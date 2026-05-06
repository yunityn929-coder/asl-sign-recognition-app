import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../controllers/recognition_controller.dart';
import '../../models/recognition_result.dart';

/// Temporary screen for testing the RecognitionController pipeline.
/// Shows camera preview and logs predictions to console.
/// Remove / replace when integrating into LearnScreen / PracticeSessionScreen.
class RecognitionTestScreen extends ConsumerStatefulWidget {
  const RecognitionTestScreen({super.key});

  @override
  ConsumerState<RecognitionTestScreen> createState() =>
      _RecognitionTestScreenState();
}

class _RecognitionTestScreenState extends ConsumerState<RecognitionTestScreen> {
  RecognitionController? _recognition;
  StreamSubscription<RecognitionResult>? _sub;
  bool _cameraReady = false;
  String _lastLabel = '-';
  double _lastConf = 0;
  bool _handDetected = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    unawaited(_startSession());
  }

  Future<void> _startSession() async {
    final status = await Permission.camera.request();
    if (!mounted) return;

    if (!status.isGranted) {
      setState(() {
        _errorText =
            'Camera permission is required to run the recognition test.';
      });
      return;
    }

    _recognition = ref.read(recognitionControllerProvider);
    _recognition!.startSession();

    _sub = _recognition!.results.listen(
      (result) {
        if (!mounted) return;

        final camReady =
            _recognition!.cameraController?.value.isInitialized == true;
        setState(() {
          _cameraReady = camReady;
          _errorText = null;
          _handDetected = result.handDetected;
          _lastLabel = result.label.isEmpty ? '-' : result.label;
          _lastConf = result.confidence;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;
        setState(() {
          _errorText = error.toString();
        });
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _recognition?.stopSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_errorText != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            )
          else if (_cameraReady)
            CameraPreview(_recognition!.cameraController!)
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  _handDetected ? 'Hand detected' : 'No hand',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  _lastLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 80,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'conf: ${(_lastConf * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
