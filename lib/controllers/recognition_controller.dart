import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/recognition_result.dart';

// ---------------------------------------------------------------------------
// Abstract interface (matches APP_FLOW.md spec)
// ---------------------------------------------------------------------------

abstract class RecognitionController {
  Stream<RecognitionResult> get results;
  CameraController? get cameraController;
  void startSession();
  void stopSession();
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

class RecognitionControllerImpl implements RecognitionController {
  static const _channel = MethodChannel('com.hiasl.app/recognition');
  static const _kConfidenceThreshold = 0.85;
  static const _kFrameIntervalMs = 100; // ~10 fps

  final _streamController = StreamController<RecognitionResult>.broadcast();

  Interpreter? _interpreter;
  List<String>? _labels;
  CameraController? _cameraController;
  bool _active = false;
  bool _processing = false;
  int _lastFrameMs = 0;

  @override
  Stream<RecognitionResult> get results => _streamController.stream;

  @override
  CameraController? get cameraController => _cameraController;

  @override
  void startSession() {
    _active = true;
    _initAndStart();
  }

  @override
  void stopSession() {
    _active = false;
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _cameraController = null;
    _channel.invokeMethod('stopSession').catchError((_) {});
  }

  Future<void> _initAndStart() async {
    try {
      _interpreter ??= await Interpreter.fromAsset(
          'assets/models/keypoint_classifier.tflite');
      _labels ??= await _loadLabels();

      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await _cameraController!.initialize();

      if (!_active) return;

      _emit(const RecognitionResult(
        label: '',
        confidence: 0,
        handDetected: false,
        landmarks: [],
      ));
      await _cameraController!.startImageStream(_onFrame);
    } catch (e) {
      debugPrint('[Recognition] init error: $e');
      if (!_streamController.isClosed) {
        _streamController.addError(Exception('Recognition init failed: $e'));
      }
    }
  }

  void _onFrame(CameraImage image) {
    if (!_active || _processing) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastFrameMs < _kFrameIntervalMs) return;
    _lastFrameMs = now;
    _processFrame(image);
  }

  Future<void> _processFrame(CameraImage image) async {
    _processing = true;
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('processFrame', {
        'yBytes': image.planes[0].bytes,
        'uBytes': image.planes[1].bytes,
        'vBytes': image.planes[2].bytes,
        'width': image.width,
        'height': image.height,
        'yRowStride': image.planes[0].bytesPerRow,
        'uvRowStride': image.planes[1].bytesPerRow,
        'uvPixelStride': image.planes[1].bytesPerPixel ?? 1,
      });

      if (!_active) return;

      if (raw == null || raw.isEmpty) {
        _emit(const RecognitionResult(
            label: '', confidence: 0, handDetected: false, landmarks: []));
        return;
      }

      final landmarks = raw.cast<double>();
      final normalised = _normalise(landmarks);
      final result = _infer(normalised);
      _emit(result);
    } catch (e) {
      debugPrint('[Recognition] frame error: $e');
      if (!_streamController.isClosed) {
        _streamController.addError(Exception('Recognition frame failed: $e'));
      }
    } finally {
      _processing = false;
    }
  }

  // Centre on wrist (landmark 0) then scale by max absolute value.
  List<double> _normalise(List<double> raw) {
    final wx = raw[0];
    final wy = raw[1];
    final centred =
        List<double>.generate(42, (i) => i.isEven ? raw[i] - wx : raw[i] - wy);
    double maxVal = 0;
    for (final v in centred) {
      if (v.abs() > maxVal) maxVal = v.abs();
    }
    if (maxVal == 0) return centred;
    return centred.map((v) => v / maxVal).toList();
  }

  RecognitionResult _infer(List<double> normalised) {
    final input = [normalised]; // [1, 42]
    final output = [List<double>.filled(26, 0.0)]; // [1, 26]
    _interpreter!.run(input, output);

    final probs = output[0];
    int maxIdx = 0;
    for (var i = 1; i < probs.length; i++) {
      if (probs[i] > probs[maxIdx]) maxIdx = i;
    }
    final confidence = probs[maxIdx];
    final label = confidence >= _kConfidenceThreshold ? _labels![maxIdx] : '';

    debugPrint(
        '[Recognition] label=$label conf=${confidence.toStringAsFixed(3)}');

    return RecognitionResult(
      label: label,
      confidence: confidence,
      handDetected: true,
      landmarks: normalised,
    );
  }

  void _emit(RecognitionResult result) {
    if (!_streamController.isClosed) _streamController.add(result);
  }

  static Future<List<String>> _loadLabels() async {
    final csv = await rootBundle
        .loadString('assets/models/keypoint_classifier_label.csv');
    return csv
        .trim()
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

final recognitionControllerProvider = Provider<RecognitionController>((ref) {
  final controller = RecognitionControllerImpl();
  ref.onDispose(controller.stopSession);
  return controller;
});
