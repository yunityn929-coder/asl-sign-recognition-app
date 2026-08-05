// Debug-only tool for capturing real feature vectors to fine-tune the
// gesture recognition model. Reached only from a kDebugMode-gated entry
// in Settings, not part of the learner-facing app flow.

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/recognition_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../data/sign_label_map.dart';
import '../../models/recognition_result.dart';
import '../../services/camera_gate.dart';
import '../../services/feature_vector_export_service.dart';

class DataCollectionScreen extends ConsumerStatefulWidget {
  const DataCollectionScreen({super.key});

  @override
  ConsumerState<DataCollectionScreen> createState() => _DataCollectionScreenState();
}

class _DataCollectionScreenState extends ConsumerState<DataCollectionScreen> {
  static const Map<CaptureMode, int> _targetPerSign = {
    CaptureMode.train: 15,
    CaptureMode.test: 10,
  };

  final FeatureVectorExportService _exportService = FeatureVectorExportService();

  Completer<void>? _releaseCompleter;
  CameraController? _cameraController;
  final CameraLensDirection _lensDirection = CameraLensDirection.front;
  bool _cameraInitialized = false;
  int _rotationDegrees = 0;

  StreamSubscription<RecognitionResult>? _resultSub;
  RecognitionResult? _lastResult;

  bool _capturing = false;

  CaptureMode _activeMode = CaptureMode.train;
  final Map<CaptureMode, int> _currentIndex = {CaptureMode.train: 0, CaptureMode.test: 0};
  final Map<CaptureMode, Map<String, int>> _capturedCounts = {
    CaptureMode.train: {},
    CaptureMode.test: {},
  };

  int get _target => _targetPerSign[_activeMode]!;
  bool get _sessionComplete => _currentIndex[_activeMode]! >= kSignLabels.length;
  String get _currentLabel =>
      kSignLabels[_sessionComplete ? kSignLabels.length - 1 : _currentIndex[_activeMode]!];
  int get _capturedForCurrent => _capturedCounts[_activeMode]![_currentLabel] ?? 0;

  @override
  void initState() {
    super.initState();
    _resultSub = ref.read(recognitionControllerProvider).results.listen(_onRecognitionResult);
    _initCamera();
  }

  @override
  void dispose() {
    _resultSub?.cancel();
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      controller.stopImageStream().catchError((_) {}).whenComplete(() {
        controller.dispose().catchError((_) {}).whenComplete(_completeRelease);
      });
    } else {
      _completeRelease();
    }
    super.dispose();
  }

  void _completeRelease() {
    if (_releaseCompleter != null && !_releaseCompleter!.isCompleted) {
      _releaseCompleter!.complete();
    }
  }

  Future<void> _initCamera() async {
    final previous = CameraGate.chain;
    _releaseCompleter = Completer<void>();
    CameraGate.chain = _releaseCompleter!.future;
    await previous;
    if (!mounted) {
      _completeRelease();
      return;
    }
    try {
      final cameras = await availableCameras();
      final selected = cameras.firstWhere(
        (c) => c.lensDirection == _lensDirection,
        orElse: () => cameras.first,
      );
      _rotationDegrees = selected.sensorOrientation % 360;
      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        _completeRelease();
        return;
      }
      _cameraController = controller;
      await _cameraController!.startImageStream(_onCameraFrame);
      setState(() => _cameraInitialized = true);
    } catch (e) {
      debugPrint('[DataCollectionScreen] camera init error: $e');
      _completeRelease();
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (!mounted) return;
    ref.read(recognitionControllerProvider).processFrame(image, _rotationDegrees);
  }

  void _onRecognitionResult(RecognitionResult result) {
    if (!mounted) return;
    setState(() => _lastResult = result);
  }

  Future<void> _capture() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      final result = _lastResult;
      if (result == null || !result.handDetected || result.landmarks.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hold the sign steady, then try again.')),
        );
        return;
      }
      final features = [...result.landmarks, ...computeEngineeredFeatures(result.landmarks)];
      final mode = _activeMode;
      final label = _currentLabel;
      try {
        await _exportService.appendSample(mode: mode, label: label, features: features);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        final counts = _capturedCounts[mode]!;
        counts[label] = (counts[label] ?? 0) + 1;
        if (counts[label]! >= _targetPerSign[mode]!) {
          _goToIndex(mode, _currentIndex[mode]! + 1);
        }
      });
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
      } else {
        _capturing = false;
      }
    }
  }

  void _goToIndex(CaptureMode mode, int index) {
    _currentIndex[mode] = index.clamp(0, kSignLabels.length);
  }

  void _skip() {
    setState(() => _goToIndex(_activeMode, _currentIndex[_activeMode]! + 1));
  }

  void _back() {
    setState(() => _goToIndex(_activeMode, _currentIndex[_activeMode]! - 1));
  }

  void _selectMode(CaptureMode mode) {
    setState(() => _activeMode = mode);
  }

  void _jumpTo(int index) {
    setState(() => _goToIndex(_activeMode, index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Data Collection (Debug)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildModeToggle(),
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _buildCameraPreview(),
              ),
            ),
            _buildInstructions(),
            _buildQuickJump(),
            _buildControls(),
            _buildFileInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: CaptureMode.values.map((mode) {
          final selected = mode == _activeMode;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: OutlinedButton(
                onPressed: () => _selectMode(mode),
                style: OutlinedButton.styleFrom(
                  backgroundColor: selected ? AppColors.primary : Colors.white,
                  foregroundColor: selected ? Colors.white : AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
                child: Text(mode == CaptureMode.train ? 'Train' : 'Held-out Test'),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_cameraInitialized || _cameraController == null) {
      return const ColoredBox(
        color: Color(0xFF1A1A1A),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    final previewSize = _cameraController!.value.previewSize!;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    final modeLabel = _activeMode == CaptureMode.train ? 'Train' : 'Held-out Test';
    if (_sessionComplete) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          '$modeLabel session complete — all ${kSignLabels.length} signs captured.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      );
    }
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        '$modeLabel — hold the sign for "$_currentLabel", then tap Capture.\n'
        'Captured: $_capturedForCurrent/$_target',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildQuickJump() {
    return Container(
      color: Colors.white,
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: kSignLabels.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, i) {
            final label = kSignLabels[i];
            final selected = !_sessionComplete && i == _currentIndex[_activeMode];
            final done = (_capturedCounts[_activeMode]![label] ?? 0) >= _target;
            return GestureDetector(
              onTap: () => _jumpTo(i),
              child: Container(
                width: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : (done ? AppColors.success.withOpacity(0.25) : AppColors.primarySoft),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _currentIndex[_activeMode]! > 0 ? _back : null,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
              ),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: _sessionComplete || _capturing ? null : _capture,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Capture'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: _sessionComplete ? null : _skip,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF7C860),
                foregroundColor: Colors.white,
              ),
              child: const Text('Skip'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileInfo() {
    final trainFile = _exportService.files[CaptureMode.train];
    final testFile = _exportService.files[CaptureMode.test];
    if (trainFile == null && testFile == null) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trainFile != null)
            SelectableText(
              'Train file: ${trainFile.path}',
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          if (testFile != null)
            SelectableText(
              'Test file: ${testFile.path}',
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
