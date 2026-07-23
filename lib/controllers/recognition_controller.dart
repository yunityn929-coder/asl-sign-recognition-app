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
//    Input tensor:  shape [1, 80] — one sample of 63 raw + 17 engineered floats.
//    Model:         assets/models/mlp_model_v2.tflite
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
import '../services/calibration_service.dart';

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
// Engineered features (mlp_model_v2) — mirrors
// asl-gesture-recognition-model/static/landmark_features.py's
// compute_engineered_features(): 10 finger-curl angles + 5 fingertip-to-palm
// distances + 2 thumb-to-fingertip distances, appended after the raw 63.
// ---------------------------------------------------------------------------

const List<List<int>> _kFingerJoints = [
  [1, 2, 3, 4], // thumb
  [5, 6, 7, 8], // index
  [9, 10, 11, 12], // middle
  [13, 14, 15, 16], // ring
  [17, 18, 19, 20], // pinky
];
const List<int> _kPalmMcps = [5, 9, 13, 17];
const List<int> _kFingertips = [4, 8, 12, 16, 20];

double _angleBetween(List<double> v1, List<double> v2) {
  final dot = v1[0] * v2[0] + v1[1] * v2[1] + v1[2] * v2[2];
  final n1 = sqrt(v1[0] * v1[0] + v1[1] * v1[1] + v1[2] * v1[2]);
  final n2 = sqrt(v2[0] * v2[0] + v2[1] * v2[1] + v2[2] * v2[2]);
  final cosTheta = (dot / (n1 * n2 + 1e-8)).clamp(-1.0, 1.0);
  return acos(cosTheta);
}

List<double> _vec(List<double> n, int to, int from) => [
      n[to * 3] - n[from * 3],
      n[to * 3 + 1] - n[from * 3 + 1],
      n[to * 3 + 2] - n[from * 3 + 2],
    ];

double _dist(List<double> n, int a, int b) {
  final v = _vec(n, a, b);
  return sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
}

// ---------------------------------------------------------------------------
// Calibration blending — boosts a class's probability when the current
// frame's landmarks closely match a user-captured calibration sample for
// that class (see CalibrationService, CalibrationScreen).
// ---------------------------------------------------------------------------

const double kCalibrationWeight = 2.0;

double _euclideanDistance(List<double> a, List<double> b) {
  double sum = 0;
  for (var i = 0; i < a.length; i++) {
    final d = a[i] - b[i];
    sum += d * d;
  }
  return sqrt(sum);
}

List<double> _computeEngineeredFeatures(List<double> n) {
  double pcx = 0, pcy = 0, pcz = 0;
  for (final m in _kPalmMcps) {
    pcx += n[m * 3];
    pcy += n[m * 3 + 1];
    pcz += n[m * 3 + 2];
  }
  pcx /= _kPalmMcps.length;
  pcy /= _kPalmMcps.length;
  pcz /= _kPalmMcps.length;

  final curlFeats = <double>[];
  for (final joints in _kFingerJoints) {
    final vA = _vec(n, joints[1], joints[0]);
    final vB = _vec(n, joints[2], joints[1]);
    final vC = _vec(n, joints[3], joints[2]);
    curlFeats.add(_angleBetween(vA, vB));
    curlFeats.add(_angleBetween(vB, vC));
  }

  final tipDists = _kFingertips.map((t) {
    final dx = n[t * 3] - pcx, dy = n[t * 3 + 1] - pcy, dz = n[t * 3 + 2] - pcz;
    return sqrt(dx * dx + dy * dy + dz * dz);
  }).toList();

  return [...curlFeats, ...tipDists, _dist(n, 4, 8), _dist(n, 4, 12)];
}

// ---------------------------------------------------------------------------
// Environment-condition classification (lighting / hand distance)
// ---------------------------------------------------------------------------

class _EnvFlags {
  final bool isTooDark;
  final bool isTooBright;
  final bool handTooClose;
  final bool handTooFar;
  const _EnvFlags(this.isTooDark, this.isTooBright, this.handTooClose, this.handTooFar);
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
  DateTime? _lastHandSeenAt;

  // Starting thresholds — tune after live testing.
  static const int _kDarkLumaThreshold = 60;
  static const int _kBrightLumaThreshold = 200;
  static const double _kHandTooFarFraction = 0.15;
  static const double _kHandTooCloseFraction = 0.75;
  static const Duration _kNoHandTimeout = Duration(seconds: 2);

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
          await Interpreter.fromAsset('assets/models/mlp_model_v2.tflite');
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
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('processFrame', {
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

      if (raw == null) {
        final timedOut = _lastHandSeenAt == null ||
            DateTime.now().difference(_lastHandSeenAt!) >= _kNoHandTimeout;
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
          noHandTimeout: timedOut,
        ));
        return;
      }

      _lastHandSeenAt = DateTime.now();

      final landmarksRaw = (raw['landmarks'] as List).cast<double>();
      final handedness = raw['handedness'] as String?;
      final envFlags = _classifyEnvironment(image, landmarksRaw);
      final normalised = _normalise(landmarksRaw);
      if (handedness == 'Left') {
        for (var i = 0; i < normalised.length; i += 3) {
          normalised[i] = -normalised[i];
        }
      }
      final result = _infer(normalised);
      _emit(result.copyWith(
        latencyMs: stopwatch.elapsedMilliseconds,
        isTooDark: envFlags.isTooDark,
        isTooBright: envFlags.isTooBright,
        handTooClose: envFlags.handTooClose,
        handTooFar: envFlags.handTooFar,
      ));
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

  _EnvFlags _classifyEnvironment(CameraImage image, List<double> landmarksRaw) {
    // Sample the luma plane at a stride for perf at 10fps.
    final yBytes = image.planes[0].bytes;
    var sum = 0;
    var count = 0;
    for (var i = 0; i < yBytes.length; i += 20) {
      sum += yBytes[i];
      count++;
    }
    final meanLuma = count == 0 ? 128 : sum / count;
    final isTooDark = meanLuma < _kDarkLumaThreshold;
    final isTooBright = meanLuma > _kBrightLumaThreshold;

    // x,y at indices i, i+1 for each of 21 landmarks (raw, pre-normalise —
    // already normalised [0,1] fractions of image width/height).
    double minX = 1, maxX = 0, minY = 1, maxY = 0;
    for (var i = 0; i < landmarksRaw.length; i += 3) {
      final x = landmarksRaw[i];
      final y = landmarksRaw[i + 1];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    final bboxFraction =
        (maxX - minX) > (maxY - minY) ? (maxX - minX) : (maxY - minY);
    final handTooFar = bboxFraction < _kHandTooFarFraction;
    final handTooClose = bboxFraction > _kHandTooCloseFraction;

    return _EnvFlags(isTooDark, isTooBright, handTooClose, handTooFar);
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
    final engineered = _computeEngineeredFeatures(normalised);
    final combined = [...normalised, ...engineered];
    final input = [combined]; // [1, 80]
    final output = [List<double>.filled(36, 0.0)]; // [1, 36]

    // DIAG — model input
    print('[DIAG] Input length: ${normalised.length}');
    print('[DIAG] Model input:  $normalised');

    _interpreter!.run(input, output);

    // DIAG — raw model output
    print('[DIAG] Raw output:   ${output[0]}');

    final probs = List<double>.from(output[0]);
    if (CalibrationService.instance.hasAnyCalibration && CalibrationService.instance.enabled) {
      double sumProbs = 0;
      for (var i = 0; i < probs.length; i++) {
        final calibSamples = CalibrationService.instance.samplesFor(kSignLabels[i]);
        if (calibSamples.isNotEmpty) {
          double bestSim = 0;
          for (final sample in calibSamples) {
            final sim = 1.0 / (1.0 + _euclideanDistance(normalised, sample));
            if (sim > bestSim) bestSim = sim;
          }
          probs[i] = probs[i] * (1.0 + kCalibrationWeight * bestSim);
        }
        sumProbs += probs[i];
      }
      if (sumProbs > 0) {
        for (var i = 0; i < probs.length; i++) {
          probs[i] /= sumProbs;
        }
      }
    }

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
