import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../core/constants/xp_constants.dart';
import '../../data/lesson_definitions.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lesson_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/tts_service.dart';
import 'widgets/results_widgets.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  final String lessonId;
  final int correctCount;
  final int totalCount;
  final List<String> missedSigns;
  final Map<String, int> learnAttempts;

  const ResultsScreen({
    super.key,
    required this.lessonId,
    required this.correctCount,
    required this.totalCount,
    required this.missedSigns,
    this.learnAttempts = const {},
  });

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  bool _initialized = false;

  int get _xpEarned =>
      kXpLessonCompletion + (widget.correctCount * kXpLearnCorrect);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    try {
      await Future.wait([
        ref.read(lessonActionsProvider(uid)).markLessonComplete(widget.lessonId),
        ref.read(userActionsProvider(uid)).addXp(_xpEarned),
      ]);
    } catch (_) {}
    try {
      await ref
          .read(firestoreServiceProvider)
          .unlockPractice(uid, widget.lessonId);
    } catch (_) {}
    try {
      await ref
          .read(firestoreServiceProvider)
          .saveSignProgress(uid, widget.lessonId, 0);
    } catch (_) {}
    try {
      final lesson = kLessons.firstWhere((l) => l.id == widget.lessonId);
      final signAccuracy =
          await ref.read(firestoreServiceProvider).savePracticeResult(
                uid: uid,
                lessonId: widget.lessonId,
                correctCount: widget.correctCount,
                totalCount: widget.totalCount,
                missedSigns: widget.missedSigns,
                xpEarned: _xpEarned,
                lessonSigns: lesson.signs,
                learnAttempts: widget.learnAttempts,
              );
      await ref
          .read(firestoreServiceProvider)
          .updateSignAccuracy(uid: uid, newAccuracy: signAccuracy);
    } catch (_) {}
    try {
      final quests = ref.read(firestoreServiceProvider);
      await Future.wait([
        quests.updateQuestProgress(uid, 'complete_lessons', 1),
        quests.updateQuestProgress(uid, 'earn_xp', _xpEarned),
        quests.updateQuestProgress(uid, 'practice_sessions', 1),
      ]);
    } catch (_) {}
    if (mounted) {
      ref
          .read(ttsServiceProvider)
          .speak('Lesson complete! You earned $_xpEarned XP');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildContent(),
              ),
            ),
            _buildButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 60),
        ResultHeader(
            correctCount: widget.correctCount, totalCount: widget.totalCount),
        const SizedBox(height: 32),
        _buildStatsRow(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStatsRow() {
    final skippedCount = widget.totalCount - widget.correctCount;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(
            value: '${widget.correctCount}',
            label: 'Correct',
            valueColor: AppColors.success,
          ),
          _StatItem(
            value: '$skippedCount',
            label: 'Skipped',
            valueColor: AppColors.warning,
          ),
          _StatItem(
            value: '+$_xpEarned',
            label: 'XP',
            valueColor: AppColors.xpGold,
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => context.go(kRouteHome),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => context
                  .pushReplacement('/lesson/${widget.lessonId}/exercise'),
              child: const Text('Practise again', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  const _StatItem({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800, color: valueColor)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ],
    );
  }
}
