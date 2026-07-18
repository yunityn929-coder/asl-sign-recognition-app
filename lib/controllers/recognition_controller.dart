// =============================================================================
// RECOGNITION PIPELINE — DATA FLOW
//
// 1. CAPTURE
//    CameraController streams CameraImage frames at ~10 fps (100 ms gate).
//    Format: YUV420 (3 planes: Y, U, V).
//
// 2. NATIVE HAND DETECTION (MethodChannel → Android)
//    Raw YUV planes + dimensions are sent to the Android side via:
//      MethodChannel('com.hiasl.app/recognition').invokeMethod('processFrame', {...})
//    The Android implementation runs MediaPipe Hands, detects a single hand,
//    and returns 21 landmarks × 3 coords (x, y, z) = 63 doubles.
//    If no hand is detected the channel returns null or an empty list.
//
// 3. NORMALISATION (_normalise)
//    Input:  List<double> of length 63 — raw x,y,z landmark coords.
//    Step a: Centre — subtract wrist (landmark 0) x,y,z from all landmarks.
//    Step b: Scale  — divide all values by the Euclidean norm of the
//            (already-centred) landmark 9, matching training-time
//            normalisation (asl-gesture-recognition-model/static/preprocessing.py).
//    Output: List<double> of length 63.
//
// 4. INFERENCE (_infer)
//    Input tensor:  shape [1, 63] — one sample of 63 floats.
//    Model:         assets/models/mlp_model.tflite
//                   Converted from the Keras MLP trained in
//                   asl-gesture-recognition-model/static/model/mlp_model.h5
//                   via tf.lite.TFLiteConverter. The accompanying
//                   label_encoder.pkl is not bundled — its class order
//                   (0-9 then A-Z, alphabetical) is reproduced by hand as
//                   kSignLabels in sign_label_map.dart.
//    Output tensor: shape [1, 36] — softmax probabilities for 36 classes.
//    Post-process:  argmax → index → label lookup in kSignLabels
//                   confidence < kRecognitionConfidenceThreshold → emit label='' (triggers no-detection hint)
//
// 5. LABELS
//    kSignLabels (lib/data/sign_label_map.dart) — 36 entries, 0-9 then A-Z.
// =============================================================================

import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../data/sign_label_map.dart';
import '../models/recognition_result.dart';

// ---------------------------------------------------------------------------
// Abstract interface (matches APP_FLOW.md spec)
// ---------------------------------------------------------------------------

abstract class RecognitionController {
  Stream<RecognitionResult> get results;
  CameraController? get cameraController;
  void startSession();
  void stopSession();
  Future<void> switchCamera(CameraLensDirection direction);
  Future<void> processFrame(CameraImage image, [int rotationDegrees = 0]);
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

class RecognitionControllerImpl implements RecognitionController {
  static const _channel = MethodChannel('com.hiasl.app/recognition');
  static const _kFrameIntervalMs = 100; // ~10 fps

  final _streamController = StreamController<RecognitionResult>.broadcast();

  Interpreter? _interpreter;
  CameraController? _cameraController;
  CameraLensDirection _lensDirection = CameraLensDirection.back;
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

  Future<void> _ensureModelLoaded() async {
    if (_interpreter == null) {
      _interpreter =
          await Interpreter.fromAsset('assets/models/mlp_model.tflite');
      print('[DIAG] Input shape:  ${_interpreter!.getInputTensor(0).shape}');
      print('[DIAG] Output shape: ${_interpreter!.getOutputTensor(0).shape}');
    }
  }

  Future<void> _initAndStart() async {
    try {
      await _ensureModelLoaded();

      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == _lensDirection,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
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
        topLabel: '',
        topConfidence: 0,
        secondLabel: '',
        secondConfidence: 0,
        isConfident: false,
      ));
      await _cameraController!.startImageStream(_onFrame);
    } catch (e) {
      debugPrint('[Recognition] init error: $e');
      if (!_streamController.isClosed) {
        _streamController.addError(Exception('Recognition init failed: $e'));
      }
    }
  }

  @override
  Future<void> switchCamera(CameraLensDirection direction) async {
    _lensDirection = direction;
    try {
      await _cameraController?.stopImageStream();
    } catch (_) {}
    await _cameraController?.dispose();
    _cameraController = null;
    if (_active) await _initAndStart();
  }

  @override
  Future<void> processFrame(CameraImage image, [int rotationDegrees = 0]) async {
    if (_processing) return;
    _processing = true;
    final stopwatch = Stopwatch()..start();
    try {
      await _ensureModelLoaded();
      final raw = await _channel.invokeMethod<List<dynamic>>('processFrame', {
        'yBytes': image.planes[0].bytes,
        'uBytes': image.planes[1].bytes,
        'vBytes': image.planes[2].bytes,
        'width': image.width,
        'height': image.height,
        'yRowStride': image.planes[0].bytesPerRow,
        'uvRowStride': image.planes[1].bytesPerRow,
        'uvPixelStride': image.planes[1].bytesPerPixel ?? 1,
        'rotationDegrees': rotationDegrees,
      });

      if (raw == null || raw.isEmpty) {
        _emit(RecognitionResult(
          label: '',
          confidence: 0,
          handDetected: false,
          landmarks: const [],
          topLabel: '',
          topConfidence: 0,
          secondLabel: '',
          secondConfidence: 0,
          isConfident: false,
          latencyMs: stopwatch.elapsedMilliseconds,
        ));
        return;
      }

      final landmarks = raw.cast<double>();
      final normalised = _normalise(landmarks);
      final result = _infer(normalised);
      _emit(result.copyWith(latencyMs: stopwatch.elapsedMilliseconds));
    } catch (e) {
      debugPrint('[Recognition] processFrame error: $e');
      if (!_streamController.isClosed) {
        _streamController.addError(Exception('Recognition frame failed: $e'));
      }
    } finally {
      _processing = false;
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
    final stopwatch = Stopwatch()..start();
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
        _emit(RecognitionResult(
          label: '',
          confidence: 0,
          handDetected: false,
          landmarks: const [],
          topLabel: '',
          topConfidence: 0,
          secondLabel: '',
          secondConfidence: 0,
          isConfident: false,
          latencyMs: stopwatch.elapsedMilliseconds,
        ));
        return;
      }

      final landmarks = raw.cast<double>();
      final normalised = _normalise(landmarks);
      final result = _infer(normalised);
      _emit(result.copyWith(latencyMs: stopwatch.elapsedMilliseconds));
    } catch (e) {
      debugPrint('[Recognition] frame error: $e');
      if (!_streamController.isClosed) {
        _streamController.addError(Exception('Recognition frame failed: $e'));
      }
    } finally {
      _processing = false;
    }
  }

  // Centre on wrist (landmark 0) then scale by the Euclidean norm of
  // (centred) landmark 9 — matches the training-time normalisation.
  List<double> _normalise(List<double> raw) {
    final wx = raw[0];
    final wy = raw[1];
    final wz = raw[2];
    final centred = List<double>.generate(63, (i) {
      switch (i % 3) {
        case 0:
          return raw[i] - wx;
        case 1:
          return raw[i] - wy;
        default:
          return raw[i] - wz;
      }
    });
    final l9x = centred[27];
    final l9y = centred[28];
    final l9z = centred[29];
    final scale = sqrt(l9x * l9x + l9y * l9y + l9z * l9z);
    if (scale == 0) return centred;
    return centred.map((v) => v / scale).toList();
  }

  RecognitionResult _infer(List<double> normalised) {
    final input = [normalised]; // [1, 63]
    final output = [List<double>.filled(36, 0.0)]; // [1, 36]

    // DIAG — model input
    print('[DIAG] Input length: ${normalised.length}');
    print('[DIAG] Model input:  $normalised');

    _interpreter!.run(input, output);

    // DIAG — raw model output
    print('[DIAG] Raw output:   ${output[0]}');

    final probs = output[0];

    // Top-2 argmax in one pass.
    int topIdx = 0;
    int secondIdx = -1;
    for (var i = 1; i < probs.length; i++) {
      if (probs[i] > probs[topIdx]) {
        secondIdx = topIdx;
        topIdx = i;
      } else if (secondIdx == -1 || probs[i] > probs[secondIdx]) {
        secondIdx = i;
      }
    }

    final topConfidence = probs[topIdx];
    final topLabel = kSignLabels[topIdx];
    final secondConfidence = secondIdx == -1 ? 0.0 : probs[secondIdx];
    final secondLabel = secondIdx == -1 ? '' : kSignLabels[secondIdx];
    final isConfident = topConfidence >= kRecognitionConfidenceThreshold;
    final label = isConfident ? topLabel : '';

    debugPrint(
        '[Recognition] label=$label conf=${topConfidence.toStringAsFixed(3)}');

    return RecognitionResult(
      label: label,
      confidence: topConfidence,
      handDetected: true,
      landmarks: normalised,
      topLabel: topLabel,
      topConfidence: topConfidence,
      secondLabel: secondLabel,
      secondConfidence: secondConfidence,
      isConfident: isConfident,
    );
  }

  void _emit(RecognitionResult result) {
    if (!_streamController.isClosed) _streamController.add(result);
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
