import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/recognition_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../data/lesson_definitions.dart';
import '../../models/lesson_model.dart';
import '../../models/recognition_result.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lesson_provider.dart';
import '../../services/feedback_service.dart';
import '../../services/firestore_service.dart';
import '../../services/quiz_service.dart';
import '../../services/tts_service.dart';
import 'widgets/feedback_widget.dart';
import 'widgets/learn_mode_body.dart';

class ExerciseScreen extends ConsumerStatefulWidget {
  final String lessonId;
  const ExerciseScreen({required this.lessonId, super.key});

  @override
  ConsumerState<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends ConsumerState<ExerciseScreen> {
  late final LessonDefinition _def;
  int _currentIndex = 0;
  final Set<int> _correctIndices = {};
  final Map<String, int> _learnAttempts = {};
  bool _showHint = false;
  bool _speakerOn = true;

  // Camera
  CameraController? _cameraController;
  static const CameraLensDirection _lensDirection = CameraLensDirection.front;
  bool _cameraInitialized = false;
  int _rotationDegrees = 0;

  // Recognition
  final FeedbackService _feedbackService = FeedbackService();
  FeedbackResult _feedbackResult = FeedbackResult.initial;
  bool _autoAdvancing = false;
  StreamSubscription<RecognitionResult>? _resultSub;

  @override
  void initState() {
    super.initState();
    _def = kLessons.firstWhere(
      (l) => l.id == widget.lessonId,
      orElse: () =>
          const LessonDefinition(id: '', section: 0, title: '', signs: []),
    );
    _resumeFromLastSignIndex();
    _resultSub = ref
        .read(recognitionControllerProvider)
        .results
        .listen(_onRecognitionResult);
    _initCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_def.signs.isNotEmpty) {
        _speakCurrentSign();
      }
    });
  }

  @override
  void dispose() {
    _resultSub?.cancel();
    _cameraController?.stopImageStream().catchError((_) {});
    _cameraController?.dispose();
    super.dispose();
  }

  void _resumeFromLastSignIndex() {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    try {
      final lessons = ref.read(lessonProvider(uid)).value;
      final lesson = lessons?.firstWhere(
        (l) => l.lessonId == widget.lessonId,
        orElse: () => LessonModel.empty(),
      );
      if (lesson != null && lesson.lastSignIndex > 0) {
        setState(() {
          _currentIndex = lesson.lastSignIndex.clamp(0, _def.signs.length - 1);
        });
      }
    } catch (_) {}
  }

  // INTEGRATION POINT (reference impl): camera + MediaPipe are initialized
  // together — MediaPipe/mlp_model.tflite loading happens lazily inside
  // RecognitionControllerImpl the first time a frame is processed, triggered
  // by _onCameraFrame below. practice_session_screen.dart should mirror this.
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final selected = cameras.firstWhere(
        (c) => c.lensDirection == _lensDirection,
        orElse: () => cameras.first,
      );
      // Sensor mount angle vs. natural (portrait) orientation.
      // Assumes device held upright; does not track live device rotation.
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
      debugPrint('[ExerciseScreen] camera init error: $e');
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (!mounted) return;
    ref.read(recognitionControllerProvider).processFrame(image, _rotationDegrees);
  }

  // INTEGRATION POINT (reference impl): this is where a recognized sign
  // feeds into the lesson flow — result.label/result.confidence come from
  // RecognitionControllerImpl (MediaPipe landmarks → mlp_model.tflite).
  // practice_session_screen.dart's timer-based scoring should consume the
  // results stream the same way.
  void _onRecognitionResult(RecognitionResult result) {
    if (!mounted) return;

    final feedback = _feedbackService.evaluate(
      topLabel: result.topLabel,
      topConfidence: result.topConfidence,
      secondLabel: result.secondLabel,
      targetLetter: _currentSign,
    );

    setState(() {
      _feedbackResult = feedback;
    });

    if (feedback.state == FeedbackState.correct && !_autoAdvancing) {
      _autoAdvancing = true;
      _correctIndices.add(_currentIndex);
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _autoAdvancing = false;
          _advance();
        }
      });
    }

    if (feedback.state == FeedbackState.correct) {
      _learnAttempts[_currentSign] =
          (_learnAttempts[_currentSign] ?? 0) + 1;
    }
  }

  String get _currentSign => _def.signs[_currentIndex];

  String _signName(String sign) {
    const digits = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9'};
    return digits.contains(sign) ? 'Number $sign' : 'Sign $sign';
  }

  void _speakCurrentSign() {
    if (_speakerOn) {
      ref.read(ttsServiceProvider).speak(_signName(_currentSign));
    }
  }

  void _goBack() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _feedbackService.reset();
        _feedbackResult = FeedbackResult.initial;
        _autoAdvancing = false;
      });
      _saveProgress();
      _speakCurrentSign();
    }
  }

  void _enterLearnMode() {
    if (_cameraInitialized && _cameraController != null) {
      _cameraController!.startImageStream(_onCameraFrame).catchError((_) {});
    }
    _feedbackService.reset();
    _learnAttempts[_currentSign] = 0;
    setState(() {
      _autoAdvancing = false;
      _feedbackResult = FeedbackResult.initial;
    });
    _speakCurrentSign();
  }

  void _advance() {
    if (_currentIndex + 1 < _def.signs.length) {
      setState(() => _currentIndex++);
      _enterLearnMode();
      _saveProgress();
    } else {
      final missed = [
        for (int i = 0; i < _def.signs.length; i++)
          if (!_correctIndices.contains(i)) _def.signs[i],
      ];
      context.pushReplacement(
        '/lesson/${widget.lessonId}/results',
        extra: {
          'correctCount': _correctIndices.length,
          'totalCount': _def.signs.length,
          'missedSigns': missed,
          'learnAttempts': _learnAttempts,
        },
      );
    }
  }

  void _saveProgress() {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    ref.read(firestoreServiceProvider).saveSignProgress(
          uid,
          widget.lessonId,
          _currentIndex,
        );
  }

  @override
  Widget build(BuildContext context) {
    if (_def.signs.isEmpty) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: const Center(child: Text('No signs to practice in this lesson.')),
      );
    }
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          appBar: _buildAppBar(),
          body: _buildLearnBody(),
        ),
        if (_showHint) _buildHintOverlay(),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        onPressed: () {
          _saveProgress();
          context.pop();
        },
      ),
      title: LinearProgressIndicator(
        value: _currentIndex / _def.signs.length,
        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
        backgroundColor: const Color(0xFFF0F0F0),
        minHeight: 8,
        borderRadius: BorderRadius.circular(4),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_currentIndex + 1} / ${_def.signs.length}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _speakerOn = !_speakerOn),
                child: Icon(
                  _speakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: _speakerOn ? AppColors.primary : AppColors.textSecondary,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLearnBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            children: [
              LearnModeBody(
                sign: _currentSign,
                onPrevious: _currentIndex > 0 ? _goBack : null,
                onNext: _autoAdvancing ? null : _advance,
                onHint: () => setState(() => _showHint = true),
              ),
              const SizedBox(height: 10),
              const Text(
                'Try it yourself',
                style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
        Expanded(child: _buildCameraSection()),
      ],
    );
  }

  Widget _buildCameraSection() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraPreview(),
          FeedbackWidget(
            state: _feedbackResult.state,
            message: _feedbackResult.message,
          ),
        ],
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
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        // previewSize is landscape (width > height); swap for portrait display
        width: previewSize.height,
        height: previewSize.width,
        child: Transform(
          alignment: Alignment.center,
          transform: _lensDirection == CameraLensDirection.front
              ? (Matrix4.identity()..scale(-1.0, 1.0, 1.0))
              : Matrix4.identity(),
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Widget _buildHintOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showHint = false),
        child: Container(
          color: Colors.black.withValues(alpha: 0.75),
          child: Stack(
            children: [
              Center(
                child: Image.asset(
                  quizImagePath(_currentSign) ?? '$kSignImagePath$_currentSign.png',
                  height: 280,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                top: 48,
                right: 20,
                child: GestureDetector(
                  onTap: () => setState(() => _showHint = false),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 22, color: AppColors.textPrimary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
