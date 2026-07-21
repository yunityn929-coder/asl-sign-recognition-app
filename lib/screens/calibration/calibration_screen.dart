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
import '../../services/camera_gate.dart';

class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key});

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen> {
  Completer<void>? _releaseCompleter;

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
    // Normal exits (see _advance/PopScope below) already await _releaseCamera()
    // before navigating, so _cameraController is usually null here already —
    // this is only a safety net for disposal paths that bypass those (hot
    // reload, forced disposal, etc). Chains completion onto the real teardown
    // instead of firing-and-forgetting, so the shared gate never unblocks the
    // next camera user before the hardware is actually closed.
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

  // Guards against completing an already-completed Completer, which throws
  // — can otherwise happen if _releaseCamera() runs after _initCamera()'s
  // own catch/early-return paths already completed the same completer.
  void _completeRelease() {
    if (_releaseCompleter != null && !_releaseCompleter!.isCompleted) {
      _releaseCompleter!.complete();
    }
  }

  Future<void> _initCamera() async {
    final previous = CameraGate.chain;
    _releaseCompleter = Completer<void>();
    CameraGate.chain = _releaseCompleter!.future;
    await previous; // wait for any prior instance to fully release the camera first
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
      debugPrint('[CalibrationScreen] camera init error: $e');
      _completeRelease();
    }
  }

  Future<void> _releaseCamera() async {
    try {
      await _cameraController?.stopImageStream();
    } catch (_) {}
    try {
      await _cameraController?.dispose();
    } catch (_) {}
    _cameraController = null;
    _cameraInitialized = false;
    _completeRelease();
    _releaseCompleter = null;
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

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear "$_currentLabel" samples?'),
        content: const Text('This removes all captured samples for this sign and can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    await CalibrationService.instance.clearClass(uid, _currentLabel);
    if (mounted) setState(() {});
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
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          title: Text(
            'Calibrate: $_currentLabel (${_currentIndex + 1}/${kSignLabels.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Clear captured samples',
              onPressed: _capturedForClass == 0 ? null : _confirmClear,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
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
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        'Hold the sign for "$_currentLabel", then tap Capture.\n'
        'Captured: $_capturedForClass/${CalibrationService.maxSamplesPerClass}',
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
            final selected = i == _currentIndex;
            return GestureDetector(
              onTap: () => setState(() => _currentIndex = i),
              child: Container(
                width: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.primarySoft,
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
              onPressed: _advance,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
              ),
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
                backgroundColor: const Color(0xFFF7C860),
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
