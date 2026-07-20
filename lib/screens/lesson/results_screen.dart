import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../core/constants/xp_constants.dart';
import 'widgets/results_widgets.dart';

class ResultsScreen extends ConsumerWidget {
  final String lessonId;
  final int correctCount;
  final int totalCount;
  final List<String> missedSigns;
  final Map<String, int> learnAttempts;
  final bool streakJustExtended;
  final bool questNewlyCompleted;

  const ResultsScreen({
    super.key,
    required this.lessonId,
    required this.correctCount,
    required this.totalCount,
    required this.missedSigns,
    this.learnAttempts = const {},
    this.streakJustExtended = false,
    this.questNewlyCompleted = false,
  });

  int get _xpEarned => kXpLessonCompletion + (correctCount * kXpLearnCorrect);

  void _handleContinue(BuildContext context) {
    if (streakJustExtended) {
      context.go(kRouteStreak, extra: {
        'justEarned': true,
        'skipQuestScreen': !questNewlyCompleted,
      });
    } else if (questNewlyCompleted) {
      context.go(kRouteQuest, extra: {'justEarned': true});
    } else {
      context.go(kRouteHome);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        ResultHeader(correctCount: correctCount, totalCount: totalCount),
        const SizedBox(height: 32),
        _buildStatsRow(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStatsRow() {
    final skippedCount = totalCount - correctCount;
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
            value: '$correctCount',
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
              onPressed: () => _handleContinue(context),
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
              onPressed: () =>
                  context.pushReplacement('/lesson/$lessonId/exercise'),
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
