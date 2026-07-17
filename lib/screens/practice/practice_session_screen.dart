import 'dart:async';

import 'package:camera/camera.dart';
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
import '../../services/quiz_service.dart';
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
  CameraLensDirection _lensDirection = CameraLensDirection.front;
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
    super.dispose();
  }

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
      await _cameraController!.startImageStream(_onCameraFrame);
      setState(() => _cameraInitialized = true);
    } catch (e) {
      debugPrint('[PracticeSessionScreen] camera init error: $e');
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
    ref.read(recognitionControllerProvider).processFrame(image);
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
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_autoAdvancing) _advance();
      });
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
    if (_currentIndex + 1 < _signs.length) {
      setState(() {
        _currentIndex++;
        _timeLeft = kDifficultySeconds[widget.difficulty] ?? 10;
        _feedbackResult = FeedbackResult.initial;
        _autoAdvancing = false;
      });
      _feedbackService.reset();
      _startCountdown();
      ref.read(ttsServiceProvider).speak(_signs[_currentIndex]);
    } else {
      _finishSession();
    }
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
    final sign = _signs[_currentIndex];
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const SizedBox(height: 12),
            _buildSignCard(sign),
            const SizedBox(height: 12),
            Expanded(child: _buildCameraSection()),
            _buildTimerBar(),
            _buildSkipButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Text(
            '${_currentIndex + 1} / ${_signs.length}',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            '✓ $_correctCount',
            style: const TextStyle(
                color: AppColors.success, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          Text(
            '${_timeLeft}s',
            style: TextStyle(
              color: _timeLeft <= 3 ? AppColors.error : AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignCard(String sign) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x15000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (kAvailableSigns.contains(sign)) ...[
            Image.asset('$kSignImagePath$sign.png', height: 160),
            const SizedBox(height: 8),
          ],
          Text(sign,
              style: const TextStyle(
                  fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 4),
          Text('Sign $sign',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
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
          FeedbackWidget(state: _feedbackResult.state, message: _feedbackResult.message),
          _buildFlipButton(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_cameraInitialized || _cameraController == null) {
      return Container(
        color: Colors.grey.shade300,
        child: const Center(child: CircularProgressIndicator()),
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
          child: const Icon(Icons.flip_camera_android_rounded, size: 22, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildTimerBar() {
    final total = kDifficultySeconds[widget.difficulty] ?? 10;
    final color = _timeLeft > total * 0.5
        ? AppColors.success
        : _timeLeft > total * 0.25
            ? AppColors.warning
            : AppColors.error;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: _timeLeft / total,
          color: color,
          backgroundColor: AppColors.primarySoft,
          minHeight: 8,
        ),
      ),
    );
  }

  Widget _buildSkipButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Center(
        child: TextButton(
          onPressed: _advance,
          child: const Text(
            'Skip →',
            style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
