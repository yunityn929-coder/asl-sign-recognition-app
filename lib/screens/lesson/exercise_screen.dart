import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/recognition_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../data/lesson_definitions.dart';
import '../../models/recognition_result.dart';
import '../../services/feedback_service.dart';
import '../../services/tts_service.dart';
import 'widgets/feedback_widget.dart';
import 'widgets/learn_mode_body.dart';
import 'widgets/quiz_mode_body.dart';

enum _Mode { learn, quiz }

class ExerciseScreen extends ConsumerStatefulWidget {
  final String lessonId;
  const ExerciseScreen({required this.lessonId, super.key});

  @override
  ConsumerState<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends ConsumerState<ExerciseScreen> {
  late final LessonDefinition _def;
  int _currentIndex = 0;
  _Mode _mode = _Mode.learn;
  bool? _answerCorrect;
  String? _tappedOption;
  int _correctCount = 0;
  final Set<int> _correctIndices = {};
  final Map<String, int> _learnAttempts = {};
  List<String> _quizOptions = const [];
  bool _buttonsDisabled = false;

  // Camera
  CameraController? _cameraController;
  CameraLensDirection _lensDirection = CameraLensDirection.front;
  bool _cameraInitialized = false;

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
    _resultSub = ref
        .read(recognitionControllerProvider)
        .results
        .listen(_onRecognitionResult);
    _initCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_def.signs.isNotEmpty) {
        ref.read(ttsServiceProvider).speak(_def.signs[0]);
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
      if (_mode == _Mode.learn) {
        await _cameraController!.startImageStream(_onCameraFrame);
      }
      setState(() => _cameraInitialized = true);
    } catch (e) {
      debugPrint('[ExerciseScreen] camera init error: $e');
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (!mounted) return;
    ref.read(recognitionControllerProvider).processFrame(image);
  }

  // INTEGRATION POINT (reference impl): this is where a recognized sign
  // feeds into the lesson flow — result.label/result.confidence come from
  // RecognitionControllerImpl (MediaPipe landmarks → mlp_model.tflite).
  // practice_session_screen.dart's timer-based scoring should consume the
  // results stream the same way.
  void _onRecognitionResult(RecognitionResult result) {
    if (!mounted || _mode != _Mode.learn) return;

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

  String get _currentSign => _def.signs[_currentIndex];

  void _enterLearnMode() {
    if (_cameraInitialized && _cameraController != null) {
      _cameraController!.startImageStream(_onCameraFrame).catchError((_) {});
    }
    _feedbackService.reset();
    _learnAttempts[_currentSign] = 0;
    setState(() {
      _mode = _Mode.learn;
      _answerCorrect = null;
      _tappedOption = null;
      _buttonsDisabled = false;
      _autoAdvancing = false;
      _feedbackResult = FeedbackResult.initial;
    });
    ref.read(ttsServiceProvider).speak(_currentSign);
  }

  void _enterQuizMode() {
    _cameraController?.stopImageStream().catchError((_) {});
    setState(() {
      _quizOptions = _generateOptions();
      _mode = _Mode.quiz;
      _answerCorrect = null;
      _tappedOption = null;
      _buttonsDisabled = false;
      _feedbackResult = FeedbackResult.initial;
    });
  }

  List<String> _generateOptions() {
    final correct = _currentSign;
    final pool = <String>{};
    for (final s in _def.signs) {
      if (s != correct) pool.add(s);
    }
    if (pool.length < 3) {
      for (final l in kLessons) {
        if (l.section == _def.section) {
          for (final s in l.signs) {
            if (s != correct) pool.add(s);
          }
        }
      }
    }
    if (pool.length < 3) {
      for (final l in kLessons) {
        for (final s in l.signs) {
          if (s != correct) pool.add(s);
        }
      }
    }
    final rng = math.Random();
    final wrongs = pool.toList()..shuffle(rng);
    return [correct, ...wrongs.take(3)]..shuffle(rng);
  }

  void _onAnswerTap(String option) {
    if (_buttonsDisabled) return;
    final correct = option == _currentSign;
    setState(() {
      _buttonsDisabled = true;
      _tappedOption = option;
      _answerCorrect = correct;
      if (correct) {
        _correctCount++;
        _correctIndices.add(_currentIndex);
      }
    });
    Future.delayed(
      Duration(milliseconds: correct ? 800 : 1200),
      () {
        if (mounted) _advance();
      },
    );
  }

  void _onSkip() => _advance();

  void _advance() {
    if (_currentIndex + 1 < _def.signs.length) {
      setState(() => _currentIndex++);
      _enterLearnMode();
    } else {
      final missed = [
        for (int i = 0; i < _def.signs.length; i++)
          if (!_correctIndices.contains(i)) _def.signs[i],
      ];
      context.pushReplacement(
        '/lesson/${widget.lessonId}/results',
        extra: {
          'correctCount': _correctCount,
          'totalCount': _def.signs.length,
          'missedSigns': missed,
          'learnAttempts': _learnAttempts,
        },
      );
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave lesson?'),
        content: const Text('Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if ((leave ?? false) && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_def.signs.isEmpty) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: const Center(child: Text('No signs to practice in this lesson.')),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: _mode == _Mode.learn ? _buildLearnBody() : _buildQuizBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        onPressed: _confirmLeave,
      ),
      title: LinearProgressIndicator(
        value: _currentIndex / _def.signs.length,
        color: const Color(0xFFFFD166),
        backgroundColor: const Color(0xFFF0F0F0),
        minHeight: 8,
        borderRadius: BorderRadius.circular(4),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Text(
              '${_currentIndex + 1} / ${_def.signs.length}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
            ),
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
                onHearIt: () =>
                    ref.read(ttsServiceProvider).speak(_currentSign),
              ),
              const SizedBox(height: 10),
              const Text(
                'Now try it yourself',
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
          _buildFlipButton(),
          _buildGotItButton(),
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

  Widget _buildFlipButton() {
    return Positioned(
      bottom: 20,
      right: 20,
      child: GestureDetector(
        onTap: _flipCamera,
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Color(0x99000000),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.flip_camera_android_rounded,
            size: 22,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildGotItButton() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 72,
      child: GestureDetector(
        onTap: _enterQuizMode,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD166),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFFC9962A),
                offset: Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'Got it! →',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111111),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: QuizModeBody(
        sign: _currentSign,
        options: _quizOptions,
        tappedOption: _tappedOption,
        answerCorrect: _answerCorrect,
        buttonsDisabled: _buttonsDisabled,
        onAnswerTap: _onAnswerTap,
        onSkip: _onSkip,
      ),
    );
  }
}
