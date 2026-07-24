import 'dart:async';

import 'package:camera/camera.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/recognition_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/difficulty_constants.dart';
import '../../core/constants/route_constants.dart';
import '../../core/constants/xp_constants.dart';
import '../../data/lesson_definitions.dart';
import '../../models/checkout_data.dart';
import '../../models/recognition_result.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/calibration_service.dart';
import '../../services/camera_gate.dart';
import '../../services/feedback_service.dart';
import '../../services/firestore_service.dart';
import '../../services/lesson_question_generator.dart';
import '../../services/tts_service.dart';
import '../lesson/widgets/feedback_widget.dart';
import '../lesson/widgets/name_entry_dialog.dart';
import '../lesson/widgets/question_text_card.dart';

// S-18 — Practice Session
class PracticeSessionScreen extends ConsumerStatefulWidget {
  final String lessonId;
  final String difficulty;
  const PracticeSessionScreen({
    required this.lessonId,
    required this.difficulty,
    super.key,
  });

  @override
  ConsumerState<PracticeSessionScreen> createState() => _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends ConsumerState<PracticeSessionScreen> {
  CameraController? _cameraController;
  bool _cameraInitialized = false;
  final CameraLensDirection _lensDirection = CameraLensDirection.front;
  int _rotationDegrees = 0;
  Completer<void>? _releaseCompleter;
  StreamSubscription<RecognitionResult>? _resultSub;
  late final LessonDefinition _def;
  late List<LessonQuestion> _questions;
  int _currentIndex = 0;
  int _sequenceIndex = 0;
  int _correctCount = 0;
  late int _timeLeft;
  Timer? _countdownTimer;
  final FeedbackService _feedbackService = FeedbackService();
  FeedbackResult _feedbackResult = FeedbackResult.initial;
  bool _autoAdvancing = false;
  bool _finishing = false;
  late DateTime _sessionStart;
  final Set<int> _correctIndices = {};
  final Set<String> _correctSigns = {};
  final AudioPlayer _audioPlayer = AudioPlayer();

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

  String get _currentTargetSign =>
      _questions[_currentIndex].signSequence[_sequenceIndex];

  @override
  void initState() {
    super.initState();
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid != null) {
      CalibrationService.instance.ensureLoaded(uid);
    }
    _timeLeft = kDifficultySeconds[widget.difficulty] ?? 10;
    _def = kLessons.firstWhere((l) => l.id == widget.lessonId);
    _questions = LessonQuestionGenerator.generate(_def, userName: _fallbackName);
    if (_questions.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pop();
      });
      return;
    }
    _sessionStart = DateTime.now();
    _resultSub =
        ref.read(recognitionControllerProvider).results.listen(_onRecognitionResult);
    _initCamera();
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePromptForName();
      if (_ttsEnabled) ref.read(ttsServiceProvider).speak(_currentTargetSign);
    });
  }

  @override
  void dispose() {
    _resultSub?.cancel();
    _countdownTimer?.cancel();
    // Chains completion onto the real async teardown (rather than firing
    // stopImageStream/dispose and forgetting about them) so the shared
    // CameraGate never unblocks the next screen's camera-open before this
    // screen's camera hardware is actually closed.
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      controller.stopImageStream().catchError((_) {}).whenComplete(() {
        controller.dispose().catchError((_) {}).whenComplete(_completeRelease);
      });
    } else {
      _completeRelease();
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  // Guards against completing an already-completed Completer, which throws.
  void _completeRelease() {
    if (_releaseCompleter != null && !_releaseCompleter!.isCompleted) {
      _releaseCompleter!.complete();
    }
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
  }

  Future<void> _initCamera() async {
    final previous = CameraGate.chain;
    _releaseCompleter = Completer<void>();
    CameraGate.chain = _releaseCompleter!.future;
    await previous; // wait for any prior screen to fully release the camera first
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
      debugPrint('[PracticeSessionScreen] camera init error: $e');
      _completeRelease();
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (!mounted) return;
    ref.read(recognitionControllerProvider).processFrame(image, _rotationDegrees);
  }

  void _onRecognitionResult(RecognitionResult result) {
    if (!mounted) return;
    if (_autoAdvancing) return;
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
    setState(() => _feedbackResult = feedback);

    if (feedback.state != FeedbackState.correct || _autoAdvancing) return;

    final question = _questions[_currentIndex];
    _correctSigns.add(_currentTargetSign);

    if (_sequenceIndex < question.signSequence.length - 1) {
      _playCorrectSound();
      setState(() => _sequenceIndex++);
      if (_ttsEnabled) ref.read(ttsServiceProvider).speak(_currentTargetSign);
      return;
    }

    _autoAdvancing = true;
    _correctCount++;
    _correctIndices.add(_currentIndex);
    _playCorrectSound();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_autoAdvancing) _advance();
    });
  }

  Future<void> _playCorrectSound() async {
    if (!_soundEnabled) return;
    try {
      await _audioPlayer.play(AssetSource('audio/success.mp3'));
    } catch (e) {
      debugPrint('[PracticeSessionScreen] SFX error: $e');
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_timeLeft <= 1) {
        timer.cancel();
        setState(() => _timeLeft = 0);
        _advance();
      } else {
        setState(() => _timeLeft--);
      }
    });
  }

  void _advance() {
    _countdownTimer?.cancel();
    if (!mounted) return;
    if (_currentIndex + 1 < _questions.length) {
      setState(() {
        _currentIndex++;
        _sequenceIndex = 0;
        _timeLeft = kDifficultySeconds[widget.difficulty] ?? 10;
        _feedbackResult = FeedbackResult.initial;
        _autoAdvancing = false;
      });
      _feedbackService.reset();
      _startCountdown();
      if (_ttsEnabled) {
        ref.read(ttsServiceProvider).speak(_signName(_currentTargetSign));
      }
    } else {
      _finishSession();
    }
  }

  String _signName(String sign) {
    const digits = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9'};
    return digits.contains(sign) ? 'Number $sign' : 'Sign $sign';
  }

  void _onExitTap() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit Practice?'),
        content: const Text('Your progress in this session will not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Going'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveResultAndAccuracy(
    String uid,
    List<String> missedSigns,
    int xp,
    int durationSeconds,
  ) async {
    final firestoreService = ref.read(firestoreServiceProvider);
    final signAccuracy = await firestoreService.savePracticeResult(
          uid: uid,
          lessonId: widget.lessonId,
          correctCount: _correctCount,
          totalCount: _questions.length,
          missedSigns: missedSigns,
          xpEarned: xp,
          lessonSigns: _def.signs,
          sessionType: 'practice',
        );
    await Future.wait([
      firestoreService.updateSignAccuracy(uid: uid, newAccuracy: signAccuracy),
      ref.read(userActionsProvider(uid)).addXp(xp),
      firestoreService.updateQuestProgress(uid, 'earn_xp', xp),
      firestoreService.updateQuestProgress(uid, 'spend_minutes', durationSeconds),
      firestoreService.recordDailyActiveSeconds(uid, durationSeconds),
    ]);
  }

  Future<void> _finishSession() async {
    // Stop accepting recognition results immediately — otherwise a frame
    // already in flight through the pipeline can still emit one more
    // RecognitionResult after this point (stopImageStream() below doesn't
    // cancel work already dispatched), and since the user is very likely
    // still holding the same correct hand shape a moment after their last
    // answer, that stray frame would re-enter the correct-answer branch and
    // double-count _correctCount (and re-trigger _finishSession itself).
    await _resultSub?.cancel();
    _resultSub = null;
    if (mounted) setState(() => _finishing = true);
    await _cameraController?.stopImageStream().catchError((_) {});

    final duration = DateTime.now().difference(_sessionStart).inSeconds;
    final accuracy = _questions.isEmpty ? 0.0 : _correctCount / _questions.length * 100;
    final xp = _correctCount * kXpLearnCorrect;

    final uid = ref.read(authStateProvider).value?.uid;
    var questNewlyCompleted = false;
    var streakJustExtended = false;
    var medalNewlyEarned = false;

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

      final missedSigns = [
        for (final sign in _def.signs)
          if (!_correctSigns.contains(sign)) sign,
      ];
      // savePracticeResult must run first (updateSignAccuracy depends on its
      // return value); the rest are independent writes run in parallel.
      await _saveResultAndAccuracy(uid, missedSigns, xp, duration).catchError((_) {});

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
      try {
        medalNewlyEarned = await firestoreService.awardMedalIfEligible(
          uid: uid,
          lessonId: widget.lessonId,
          difficulty: widget.difficulty,
          allCorrect: _correctCount == _questions.length && _questions.isNotEmpty,
        );
      } catch (_) {}
    }

    final checkoutData = CheckoutData(
      xpEarned: xp,
      accuracyPercent: accuracy,
      durationSeconds: duration,
      sessionType: 'practice',
      lessonId: widget.lessonId,
      streakJustExtended: streakJustExtended,
      questNewlyCompleted: questNewlyCompleted,
      difficulty: widget.difficulty,
      correctCount: _correctCount,
      totalCount: _questions.length,
      medalNewlyEarned: medalNewlyEarned,
    );

    if (mounted) {
      context.pushReplacement(kRouteCheckout, extra: checkoutData);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return const Scaffold(body: SizedBox.shrink());
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onExitTap();
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 12),
                  _buildSignCard(),
                  const SizedBox(height: 16),
                  Expanded(child: _buildCameraSection()),
                ],
              ),
            ),
          ),
          if (_finishing)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.white,
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final uid = ref.read(authStateProvider).value?.uid;
    final user = uid != null ? ref.watch(userProvider(uid)).value : null;
    CalibrationService.instance.enabled = user?.calibrationEnabled ?? true;
    final ttsEnabled = user?.ttsEnabled ?? true;
    final soundEnabled = user?.soundEnabled ?? true;
    final speakerOn = ttsEnabled && soundEnabled;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: _onExitTap,
            child: const Icon(Icons.arrow_back_ios_rounded,
                color: AppColors.textPrimary, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_currentIndex + 1) / _questions.length,
                backgroundColor: AppColors.primarySoft,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_currentIndex + 1} / ${_questions.length}',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
    );
  }

  void _toggleSound(String uid, bool currentlyOn) {
    final next = !currentlyOn;
    ref.read(userActionsProvider(uid)).updateSettings({
      'ttsEnabled': next,
      'soundEnabled': next,
    });
  }

  Widget _buildSignCard() {
    final question = _questions[_currentIndex];
    if (question.displayText != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Stack(
          children: [
            QuestionTextCard(
              question: question,
              sequenceIndex: _sequenceIndex,
              onPrevious: null,
              onNext: _advance,
              onHint: () {},
            ),
            Positioned(
              top: 12,
              right: 56,
              child: _CircularTimer(
                timeLeft: _timeLeft,
                totalTime: kDifficultySeconds[widget.difficulty] ?? 10,
              ),
            ),
          ],
        ),
      );
    }

    final sign = _currentTargetSign;
    return Container(
      width: double.infinity,
      height: 280,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x15000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  sign,
                  style: const TextStyle(
                    fontSize: 96,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _signName(sign),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _advance,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.xpGold,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Skip This',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: _CircularTimer(
              timeLeft: _timeLeft,
              totalTime: kDifficultySeconds[widget.difficulty] ?? 10,
            ),
          ),
        ],
      ),
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
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
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
}

class _CircularTimer extends StatelessWidget {
  final int timeLeft;
  final int totalTime;

  const _CircularTimer({required this.timeLeft, required this.totalTime});

  @override
  Widget build(BuildContext context) {
    final progress = 1.0 - (timeLeft / totalTime).clamp(0.0, 1.0);

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation(AppColors.primarySoft),
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation(
                  timeLeft <= 3 ? AppColors.error : AppColors.primary),
            ),
          ),
          Text(
            '$timeLeft',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: timeLeft <= 3 ? AppColors.error : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
