import 'dart:async';

import 'package:camera/camera.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/recognition_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/xp_constants.dart';
import '../../data/lesson_definitions.dart';
import '../../models/lesson_model.dart';
import '../../models/recognition_result.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lesson_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/calibration_service.dart';
import '../../services/feedback_service.dart';
import '../../services/firestore_service.dart';
import '../../services/lesson_question_generator.dart';
import '../../services/quiz_service.dart';
import '../../services/tts_service.dart';
import 'widgets/feedback_widget.dart';
import 'widgets/learn_mode_body.dart';
import 'widgets/name_entry_dialog.dart';
import 'widgets/question_text_card.dart';

class ExerciseScreen extends ConsumerStatefulWidget {
  final String lessonId;
  const ExerciseScreen({required this.lessonId, super.key});

  @override
  ConsumerState<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends ConsumerState<ExerciseScreen> {
  late final LessonDefinition _def;
  late List<LessonQuestion> _questions;
  int _currentIndex = 0;
  int _sequenceIndex = 0;
  final Set<int> _correctQuestions = {};
  final Set<String> _correctSigns = {};
  final Map<String, int> _learnAttempts = {};
  bool _showHint = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Camera
  CameraController? _cameraController;
  static const CameraLensDirection _lensDirection = CameraLensDirection.front;
  bool _cameraInitialized = false;
  int _rotationDegrees = 0;

  // Recognition
  final FeedbackService _feedbackService = FeedbackService();
  FeedbackResult _feedbackResult = FeedbackResult.initial;
  bool _autoAdvancing = false;
  bool _finishing = false;
  StreamSubscription<RecognitionResult>? _resultSub;

  bool get _ttsEnabled {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return true;
    return ref.read(userProvider(uid)).value?.ttsEnabled ?? true;
  }

  bool get _soundEnabled {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return true;
    return ref.read(userProvider(uid)).value?.soundEnabled ?? true;
  }

  String get _fallbackName {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return 'ASL';
    final name = ref.read(userProvider(uid)).value?.displayName;
    return (name == null || name.trim().isEmpty) ? 'ASL' : name;
  }

  @override
  void initState() {
    super.initState();
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid != null) {
      CalibrationService.instance.ensureLoaded(uid);
    }
    _def = kLessons.firstWhere(
      (l) => l.id == widget.lessonId,
      orElse: () =>
          const LessonDefinition(id: '', section: 0, title: '', signs: []),
    );
    _questions = LessonQuestionGenerator.generate(_def, userName: _fallbackName);
    _resumeFromLastQuestionIndex();
    _resultSub = ref
        .read(recognitionControllerProvider)
        .results
        .listen(_onRecognitionResult);
    _initCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePromptForName();
      if (_questions.isNotEmpty) {
        _speakCurrentSign();
      }
    });
  }

  @override
  void dispose() {
    _resultSub?.cancel();
    _cameraController?.stopImageStream().catchError((_) {});
    _cameraController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _maybePromptForName() async {
    if (_def.contentType != LessonContentType.nameEntry || !mounted) return;
    final entered = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => NameEntryDialog(initialName: _fallbackName),
    );
    final name = (entered != null && entered.isNotEmpty) ? entered : _fallbackName;
    if (!mounted) return;
    setState(() {
      _questions = LessonQuestionGenerator.generate(_def, userName: name);
      _currentIndex = 0;
      _sequenceIndex = 0;
    });
    _speakCurrentSign();
  }

  void _resumeFromLastQuestionIndex() {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    try {
      final lessons = ref.read(lessonProvider(uid)).value;
      final lesson = lessons?.firstWhere(
        (l) => l.lessonId == widget.lessonId,
        orElse: () => LessonModel.empty(),
      );
      if (lesson != null && lesson.lastSignIndex > 0 && _questions.isNotEmpty) {
        setState(() {
          _currentIndex = lesson.lastSignIndex.clamp(0, _questions.length - 1);
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
    if (_autoAdvancing) return;
    if (_questions.isEmpty) return;

    final feedback = _feedbackService.evaluate(
      topLabel: result.topLabel,
      topConfidence: result.topConfidence,
      secondLabel: result.secondLabel,
      secondConfidence: result.secondConfidence,
      targetLetter: _currentTargetSign,
      isTooDark: result.isTooDark,
      isTooBright: result.isTooBright,
      handTooClose: result.handTooClose,
      handTooFar: result.handTooFar,
      noHandTimeout: result.noHandTimeout,
    );

    setState(() {
      _feedbackResult = feedback;
    });

    if (feedback.state != FeedbackState.correct || _autoAdvancing) return;

    final question = _questions[_currentIndex];
    _correctSigns.add(_currentTargetSign);
    _learnAttempts[_currentTargetSign] = (_learnAttempts[_currentTargetSign] ?? 0) + 1;

    if (_sequenceIndex < question.signSequence.length - 1) {
      // Mid-sequence sign — advance within the same question without the
      // full correct-and-hold flow, so multi-sign words/numbers keep moving.
      _playCorrectSound();
      setState(() => _sequenceIndex++);
      _speakCurrentSign();
      return;
    }

    _autoAdvancing = true;
    _correctQuestions.add(_currentIndex);
    _playCorrectSound();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _autoAdvancing = false;
        _advance();
      }
    });
  }

  Future<void> _playCorrectSound() async {
    if (!_soundEnabled) return;
    try {
      await _audioPlayer.play(AssetSource('audio/success.mp3'));
    } catch (e) {
      debugPrint('[ExerciseScreen] SFX error: $e');
    }
  }

  String get _currentTargetSign =>
      _questions[_currentIndex].signSequence[_sequenceIndex];

  String _signName(String sign) {
    const digits = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9'};
    return digits.contains(sign) ? 'Number $sign' : 'Sign $sign';
  }

  void _speakCurrentSign() {
    if (_ttsEnabled) {
      ref.read(ttsServiceProvider).speak(_signName(_currentTargetSign));
    }
  }

  void _goBack() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _sequenceIndex = 0;
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
    _learnAttempts[_currentTargetSign] = 0;
    setState(() {
      _autoAdvancing = false;
      _feedbackResult = FeedbackResult.initial;
    });
    _speakCurrentSign();
  }

  void _advance() {
    if (_currentIndex + 1 < _questions.length) {
      setState(() {
        _currentIndex++;
        _sequenceIndex = 0;
      });
      _enterLearnMode();
      _saveProgress();
    } else {
      _finishLesson();
    }
  }

  Future<void> _finishLesson() async {
    if (mounted) setState(() => _finishing = true);
    await _resultSub?.cancel();
    await _cameraController?.stopImageStream().catchError((_) {});
    final missed = [
      for (final sign in _def.signs)
        if (!_correctSigns.contains(sign)) sign,
    ];
    final correctCount = _correctQuestions.length;
    final totalCount = _questions.length;
    final xpEarned = kXpLessonCompletion + (correctCount * kXpLearnCorrect);

    final uid = ref.read(authStateProvider).value?.uid;
    var streakJustExtended = false;
    var questNewlyCompleted = false;

    if (uid != null) {
      final firestoreService = ref.read(firestoreServiceProvider);
      final today = DateTime.now().toIso8601String().substring(0, 10);

      var wasStreakAlreadyUpdatedToday = true;
      var beforeCompletedIds = <String>{};
      try {
        final beforeUser = await firestoreService.getUserOnce(uid);
        wasStreakAlreadyUpdatedToday = beforeUser?.lastStreakDate == today;
      } catch (_) {}
      try {
        final beforeQuests = await firestoreService.getDailyQuests(uid);
        beforeCompletedIds = beforeQuests?.quests
                .where((q) => q.completed)
                .map((q) => q.id)
                .toSet() ??
            {};
      } catch (_) {}

      try {
        await Future.wait([
          ref.read(lessonActionsProvider(uid)).markLessonComplete(widget.lessonId),
          ref.read(userActionsProvider(uid)).addXp(xpEarned),
        ]);
      } catch (_) {}
      try {
        await firestoreService.unlockPractice(uid, widget.lessonId);
      } catch (_) {}
      try {
        await firestoreService.saveSignProgress(uid, widget.lessonId, 0);
      } catch (_) {}
      try {
        final lesson = kLessons.firstWhere((l) => l.id == widget.lessonId);
        final signAccuracy = await firestoreService.savePracticeResult(
              uid: uid,
              lessonId: widget.lessonId,
              correctCount: correctCount,
              totalCount: totalCount,
              missedSigns: missed,
              xpEarned: xpEarned,
              lessonSigns: lesson.signs,
              learnAttempts: _learnAttempts,
            );
        await firestoreService.updateSignAccuracy(uid: uid, newAccuracy: signAccuracy);
      } catch (_) {}
      try {
        await Future.wait([
          firestoreService.updateQuestProgress(uid, 'complete_lessons', 1),
          firestoreService.updateQuestProgress(uid, 'earn_xp', xpEarned),
        ]);
      } catch (_) {}

      try {
        final afterUser = await firestoreService.getUserOnce(uid);
        streakJustExtended =
            !wasStreakAlreadyUpdatedToday && afterUser?.lastStreakDate == today;
      } catch (_) {}
      try {
        final afterQuests = await firestoreService.getDailyQuests(uid);
        questNewlyCompleted = afterQuests?.quests.any(
                (q) => q.completed && !beforeCompletedIds.contains(q.id)) ??
            false;
      } catch (_) {}
    }

    if (!mounted) return;
    context.pushReplacement(
      '/lesson/${widget.lessonId}/results',
      extra: {
        'correctCount': correctCount,
        'totalCount': totalCount,
        'missedSigns': missed,
        'learnAttempts': _learnAttempts,
        'streakJustExtended': streakJustExtended,
        'questNewlyCompleted': questNewlyCompleted,
      },
    );
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
    if (_questions.isEmpty) {
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
        if (_finishing)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.white,
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            ),
          ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final uid = ref.read(authStateProvider).value?.uid;
    final user = uid != null ? ref.watch(userProvider(uid)).value : null;
    CalibrationService.instance.enabled = user?.calibrationEnabled ?? true;
    final ttsEnabled = user?.ttsEnabled ?? true;
    final soundEnabled = user?.soundEnabled ?? true;
    final speakerOn = ttsEnabled && soundEnabled;

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
        value: _currentIndex / _questions.length,
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
                '${_currentIndex + 1} / ${_questions.length}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: uid == null ? null : () => _toggleSound(uid, speakerOn),
                child: Icon(
                  speakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: speakerOn ? AppColors.primary : AppColors.textSecondary,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _toggleSound(String uid, bool currentlyOn) {
    final next = !currentlyOn;
    ref.read(userActionsProvider(uid)).updateSettings({
      'ttsEnabled': next,
      'soundEnabled': next,
    });
  }

  Widget _buildLearnBody() {
    final question = _questions[_currentIndex];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(
            children: [
              question.displayText == null
                  ? LearnModeBody(
                      sign: _currentTargetSign,
                      onPrevious: _currentIndex > 0 ? _goBack : null,
                      onNext: _autoAdvancing ? null : _advance,
                      onHint: () => setState(() => _showHint = true),
                    )
                  : QuestionTextCard(
                      question: question,
                      sequenceIndex: _sequenceIndex,
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
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          // previewSize is landscape (width > height); swap for portrait display
          width: previewSize.height,
          height: previewSize.width,
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
                  quizImagePath(_currentTargetSign) ??
                      '$kSignImagePath$_currentTargetSign.png',
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
