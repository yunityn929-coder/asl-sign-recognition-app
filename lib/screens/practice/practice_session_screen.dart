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
import '../../services/feedback_service.dart';
import '../../services/firestore_service.dart';
import '../../services/tts_service.dart';
import '../lesson/widgets/feedback_widget.dart';

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
  StreamSubscription<RecognitionResult>? _resultSub;
  late List<String> _signs;
  int _currentIndex = 0;
  int _correctCount = 0;
  late int _timeLeft;
  Timer? _countdownTimer;
  final FeedbackService _feedbackService = FeedbackService();
  FeedbackResult _feedbackResult = FeedbackResult.initial;
  bool _autoAdvancing = false;
  late DateTime _sessionStart;
  final Set<int> _correctIndices = {};
  bool _speakerOn = true;
  bool _showCorrect = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _timeLeft = kDifficultySeconds[widget.difficulty] ?? 10;
    _signs = kLessons.firstWhere((l) => l.id == widget.lessonId).signs;
    if (_signs.isEmpty) {
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
      ref.read(ttsServiceProvider).speak(_signs[0]);
    });
  }

  @override
  void dispose() {
    _resultSub?.cancel();
    _countdownTimer?.cancel();
    _cameraController?.stopImageStream().catchError((_) {});
    _cameraController?.dispose();
    _audioPlayer.dispose();
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
      debugPrint('[PracticeSessionScreen] camera init error: $e');
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (!mounted) return;
    ref.read(recognitionControllerProvider).processFrame(image, _rotationDegrees);
  }

  void _onRecognitionResult(RecognitionResult result) {
    if (!mounted) return;
    final feedback = _feedbackService.evaluate(
      topLabel: result.topLabel,
      topConfidence: result.topConfidence,
      secondLabel: result.secondLabel,
      targetLetter: _signs[_currentIndex],
    );
    setState(() => _feedbackResult = feedback);

    if (feedback.state == FeedbackState.correct && !_autoAdvancing) {
      _autoAdvancing = true;
      _correctCount++;
      _correctIndices.add(_currentIndex);
      _playCorrectSound();
      setState(() => _showCorrect = true);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _showCorrect = false);
        if (_autoAdvancing) _advance();
      });
    }
  }

  Future<void> _playCorrectSound() async {
    if (!_speakerOn) return;
    try {
      await _audioPlayer.play(AssetSource('audio/success.mp3'));
    } catch (_) {}
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
    setState(() => _showCorrect = false);
    if (_currentIndex + 1 < _signs.length) {
      setState(() {
        _currentIndex++;
        _timeLeft = kDifficultySeconds[widget.difficulty] ?? 10;
        _feedbackResult = FeedbackResult.initial;
        _autoAdvancing = false;
      });
      _feedbackService.reset();
      _startCountdown();
      if (_speakerOn) {
        ref.read(ttsServiceProvider).speak(_signName(_signs[_currentIndex]));
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

  Future<void> _finishSession() async {
    _autoAdvancing = false;
    await _cameraController?.stopImageStream().catchError((_) {});

    final duration = DateTime.now().difference(_sessionStart).inSeconds;
    final accuracy = _signs.isEmpty ? 0.0 : _correctCount / _signs.length * 100;
    final xp = _correctCount * kXpLearnCorrect;
    final checkoutData = CheckoutData(
      xpEarned: xp,
      accuracyPercent: accuracy,
      durationSeconds: duration,
      sessionType: 'practice',
      lessonId: widget.lessonId,
      streakExtended: false,
      difficulty: widget.difficulty,
      correctCount: _correctCount,
      totalCount: _signs.length,
    );

    try {
      final uid = ref.read(authStateProvider).value?.uid;
      if (uid != null) {
        final lesson = kLessons.firstWhere((l) => l.id == widget.lessonId);
        final missedSigns = [
          for (var i = 0; i < _signs.length; i++)
            if (!_correctIndices.contains(i)) _signs[i],
        ];
        final signAccuracy = await ref.read(firestoreServiceProvider).savePracticeResult(
              uid: uid,
              lessonId: widget.lessonId,
              correctCount: _correctCount,
              totalCount: _signs.length,
              missedSigns: missedSigns,
              xpEarned: xp,
              lessonSigns: lesson.signs,
            );
        await ref
            .read(firestoreServiceProvider)
            .updateSignAccuracy(uid: uid, newAccuracy: signAccuracy);
        await ref.read(firestoreServiceProvider).updateQuestProgress(uid, 'practice_sessions', 1);
        await ref.read(firestoreServiceProvider).updateQuestProgress(uid, 'earn_xp', xp);
      }
    } catch (_) {}

    if (mounted) {
      context.pushReplacement(kRouteCheckout, extra: checkoutData);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_signs.isEmpty) {
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
        ],
      ),
    );
  }

  Widget _buildTopBar() {
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
                value: (_currentIndex + 1) / _signs.length,
                backgroundColor: AppColors.primarySoft,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_currentIndex + 1} / ${_signs.length}',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
    );
  }

  Widget _buildSignCard() {
    final sign = _signs[_currentIndex];
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
            if (_showCorrect)
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, value, child) {
                    return Opacity(opacity: value, child: child);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.5, end: 1.0),
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) {
                            return Transform.scale(scale: scale, child: child);
                          },
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Text(
                            'Correct!',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Visibility(
              visible: !_showCorrect,
              child: FeedbackWidget(
                state: _feedbackResult.state,
                message: _feedbackResult.message,
              ),
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
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: previewSize.height,
        height: previewSize.width,
        child: _lensDirection == CameraLensDirection.front
            ? Transform.flip(flipX: true, child: CameraPreview(_cameraController!))
            : CameraPreview(_cameraController!),
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
