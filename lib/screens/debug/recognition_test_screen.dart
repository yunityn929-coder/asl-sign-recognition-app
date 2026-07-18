// Physical-device diagnostic screen for evaluating real-world gesture
// recognition performance. NOT part of the learner-facing app flow — reached
// only from a kDebugMode-gated entry in Settings (see settings_screen.dart).
//
// How it's used: the tester selects the letter/digit they are ABOUT TO SIGN
// (ground truth), holds the sign in front of the camera for a few seconds,
// then taps the next target. Every processed frame while a session is
// active is logged with (ground truth, model prediction, confidence,
// latency). "Export CSV" writes the buffered session to disk for the
// analysis script in docs/analysis/analyze_recognition_log.py.
//
// See docs/GESTURE_TESTING_PROTOCOL.md for the full test procedure.

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/recognition_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../data/sign_label_map.dart';
import '../../models/recognition_result.dart';
import '../../services/test_logger_service.dart';

class RecognitionTestScreen extends ConsumerStatefulWidget {
  const RecognitionTestScreen({super.key});

  @override
  ConsumerState<RecognitionTestScreen> createState() =>
      _RecognitionTestScreenState();
}

class _RecognitionTestScreenState extends ConsumerState<RecognitionTestScreen> {
  CameraController? _cameraController;
  CameraLensDirection _lensDirection = CameraLensDirection.front;
  bool _cameraInitialized = false;
  int _rotationDegrees = 0;

  StreamSubscription<RecognitionResult>? _resultSub;
  RecognitionResult? _lastResult;

  String _selectedTarget = kSignLabels.first;
  final _sessionNameController = TextEditingController(text: 'session1');
  bool _sessionActive = false;
  String? _lastExportPath;

  @override
  void initState() {
    super.initState();
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
    // Don't wipe an unexported session's buffer on accidental navigation —
    // only endSession() explicitly (via the Stop button) clears it.
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
      debugPrint('[RecognitionTestScreen] camera init error: $e');
    }
  }

  Future<void> _flipCamera() async {
    setState(() => _cameraInitialized = false);
    _lensDirection = _lensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    try {
      await _cameraController?.stopImageStream();
    } catch (_) {}
    await _cameraController?.dispose();
    _cameraController = null;
    await _initCamera();
  }

  void _onCameraFrame(CameraImage image) {
    if (!mounted) return;
    ref.read(recognitionControllerProvider).processFrame(image, _rotationDegrees);
  }

  void _onRecognitionResult(RecognitionResult result) {
    if (!mounted) return;
    setState(() => _lastResult = result);

    final logger = ref.read(testLoggerServiceProvider);
    if (_sessionActive) {
      logger.log(TestLogEntry(
        timestamp: DateTime.now(),
        targetLetter: _selectedTarget,
        topLabel: result.topLabel,
        topConfidence: result.topConfidence,
        secondLabel: result.secondLabel,
        secondConfidence: result.secondConfidence,
        handDetected: result.handDetected,
        isConfident: result.isConfident,
        latencyMs: result.latencyMs,
      ));
    }
  }

  void _toggleSession() {
    final logger = ref.read(testLoggerServiceProvider);
    setState(() {
      if (_sessionActive) {
        _sessionActive = false;
      } else {
        logger.startSession(_sessionNameController.text.trim().isEmpty
            ? 'session'
            : _sessionNameController.text.trim());
        _sessionActive = true;
        _lastExportPath = null;
      }
    });
  }

  Future<void> _export() async {
    final logger = ref.read(testLoggerServiceProvider);
    if (logger.entryCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logged frames yet.')),
      );
      return;
    }
    try {
      final file = await logger.exportCsv();
      setState(() => _lastExportPath = file.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final logger = ref.watch(testLoggerServiceProvider);
    final stats = logger.perLetterStats[_selectedTarget];
    final targetCorrect = stats?[0] ?? 0;
    final targetTotal = stats?[1] ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Recognition Test (Debug)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_android_rounded),
            onPressed: _flipCamera,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(flex: 5, child: _buildCameraPreview()),
            _buildHud(targetCorrect, targetTotal, logger.entryCount),
            _buildSessionControls(),
            Expanded(flex: 4, child: _buildTargetGrid()),
          ],
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
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity(),
            child: CameraPreview(_cameraController!),
          ),
        ),
      ),
    );
  }

  Widget _buildHud(int targetCorrect, int targetTotal, int totalLogged) {
    final r = _lastResult;
    final overallAccuracy = targetTotal == 0
        ? '—'
        : '${(100 * targetCorrect / targetTotal).toStringAsFixed(0)}%';
    return Container(
      color: const Color(0xFF111111),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r == null
                ? 'Waiting for first frame…'
                : 'top: ${r.topLabel.isEmpty ? '-' : r.topLabel} '
                    '(${(r.topConfidence * 100).toStringAsFixed(1)}%)   '
                    '2nd: ${r.secondLabel.isEmpty ? '-' : r.secondLabel} '
                    '(${(r.secondConfidence * 100).toStringAsFixed(1)}%)   '
                    'hand: ${r.handDetected}   '
                    'latency: ${r.latencyMs}ms',
            style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 4),
          Text(
            'target: $_selectedTarget   accuracy on target: $overallAccuracy '
            '($targetCorrect/$targetTotal)   session frames logged: $totalLogged',
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionControls() {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _sessionNameController,
              enabled: !_sessionActive,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'session tag (e.g. yuni_indoor_daylight)',
                labelStyle: TextStyle(color: Colors.white54, fontSize: 11),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _toggleSession,
            style: ElevatedButton.styleFrom(
              backgroundColor: _sessionActive ? AppColors.error : AppColors.success,
            ),
            child: Text(_sessionActive ? 'Stop' : 'Start'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _export,
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetGrid() {
    return Container(
      color: const Color(0xFF0A0A0A),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_lastExportPath != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SelectableText(
                'Exported: $_lastExportPath',
                style: const TextStyle(color: Colors.amber, fontSize: 11),
              ),
            ),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: kSignLabels.length,
              itemBuilder: (context, i) {
                final label = kSignLabels[i];
                final selected = label == _selectedTarget;
                final letterStats = ref.read(testLoggerServiceProvider).perLetterStats[label];
                final hasData = letterStats != null && letterStats[1] > 0;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTarget = label),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : const Color(0xFF222222),
                      borderRadius: BorderRadius.circular(6),
                      border: hasData && !selected
                          ? Border.all(color: Colors.white24)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
