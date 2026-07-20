// Optional per-user calibration flow — captures a handful of normalized
// landmark samples per sign class to help CalibrationService boost
// recognition confidence for this user's hand/camera/lighting. Reached
// from Settings ("Calibrate my signs").

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/recognition_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../data/sign_label_map.dart';
import '../../models/recognition_result.dart';
import '../../providers/auth_provider.dart';
import '../../services/calibration_service.dart';

class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key});

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen> {
  CameraController? _cameraController;
  final CameraLensDirection _lensDirection = CameraLensDirection.front;
  bool _cameraInitialized = false;
  int _rotationDegrees = 0;

  StreamSubscription<RecognitionResult>? _resultSub;
  RecognitionResult? _lastResult;

  int _currentIndex = 0;
  bool _readyToPop = false;

  String get _currentLabel => kSignLabels[_currentIndex];
  int get _capturedForClass =>
      CalibrationService.instance.samplesFor(_currentLabel).length;

  @override
  void initState() {
    super.initState();
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid != null) {
      CalibrationService.instance.ensureLoaded(uid);
    }
    _resultSub = ref
        .read(recognitionControllerProvider)
        .results
        .listen(_onRecognitionResult);
    _initCamera();
  }

  @override
  void dispose() {
    _resultSub?.cancel();
    _cameraController?.stopImageStream().catchError((_) {});
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
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
        controller.dispose();
        return;
      }
      _cameraController = controller;
      await _cameraController!.startImageStream(_onCameraFrame);
      setState(() => _cameraInitialized = true);
    } catch (e) {
      debugPrint('[CalibrationScreen] camera init error: $e');
    }
  }

  Future<void> _releaseCamera() async {
    try {
      await _cameraController?.stopImageStream();
    } catch (_) {}
    await _cameraController?.dispose();
    _cameraController = null;
  }

  void _onCameraFrame(CameraImage image) {
    if (!mounted) return;
    ref.read(recognitionControllerProvider).processFrame(image, _rotationDegrees);
  }

  void _onRecognitionResult(RecognitionResult result) {
    if (!mounted) return;
    setState(() => _lastResult = result);
  }

  void _advance() async {
    if (_currentIndex + 1 < kSignLabels.length) {
      setState(() => _currentIndex++);
    } else {
      await _releaseCamera();
      if (!mounted) return;
      setState(() => _readyToPop = true);
      if (context.mounted) context.pop();
    }
  }

  void _capture() {
    final result = _lastResult;
    if (result != null && result.handDetected && result.landmarks.isNotEmpty) {
      final uid = ref.read(authStateProvider).value?.uid;
      if (uid != null) {
        CalibrationService.instance.addSample(uid, _currentLabel, result.landmarks);
      }
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hold the sign steady, then try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _readyToPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _releaseCamera();
        if (!mounted) return;
        setState(() => _readyToPop = true);
        if (context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(
              'Calibrate: $_currentLabel (${_currentIndex + 1}/${kSignLabels.length})'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(flex: 5, child: _buildCameraPreview()),
              _buildInstructions(),
              _buildQuickJump(),
              _buildControls(),
            ],
          ),
        ),
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
    return Container(
      color: const Color(0xFF111111),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        'Hold the sign for "$_currentLabel", then tap Capture.\n'
        'Captured: $_capturedForClass/${CalibrationService.maxSamplesPerClass}',
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
    );
  }

  Widget _buildQuickJump() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: kSignLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final label = kSignLabels[i];
          final selected = i == _currentIndex;
          return GestureDetector(
            onTap: () => setState(() => _currentIndex = i),
            child: Container(
              width: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : const Color(0xFF222222),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _advance,
              child: const Text('Skip'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: _capture,
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
              onPressed: _advance,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('Next'),
            ),
          ),
        ],
      ),
    );
  }
}
