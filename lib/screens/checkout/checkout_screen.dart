import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../data/lesson_definitions.dart';
import '../../models/checkout_data.dart';

// S-19 — Session Checkout
class CheckoutScreen extends StatelessWidget {
  final CheckoutData checkoutData;
  const CheckoutScreen({required this.checkoutData, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  children: [
                    _ResultHeader(checkoutData: checkoutData),
                    const SizedBox(height: 24),
                    _StatsCard(checkoutData: checkoutData),
                  ],
                ),
              ),
            ),
            _buildContinueButton(context),
          ],
        ),
      ),
    );
  }

  void _handleContinue(BuildContext context) {
    if (checkoutData.streakJustExtended) {
      context.go(kRouteStreak, extra: {
        'justEarned': true,
        'skipQuestScreen': !checkoutData.questNewlyCompleted,
      });
    } else if (checkoutData.questNewlyCompleted) {
      context.go(kRouteQuest, extra: {'justEarned': true});
    } else {
      context.go(kRouteHome);
    }
  }

  Widget _buildContinueButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _handleContinue(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Continue',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ),
      ),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  final CheckoutData checkoutData;
  const _ResultHeader({required this.checkoutData});

  String get _emoji {
    final a = checkoutData.accuracyPercent;
    if (a >= 90) return '🏆';
    if (a >= 70) return '⭐';
    if (a >= 50) return '👍';
    return '💪';
  }

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final lessonDef = kLessons.firstWhere(
      (l) => l.id == checkoutData.lessonId,
      orElse: () => const LessonDefinition(id: '', section: 0, title: '', signs: []),
    );
    final lessonTitle = lessonDef.title.isNotEmpty ? lessonDef.title : checkoutData.lessonId;

    return Column(
      children: [
        Text(_emoji, style: const TextStyle(fontSize: 72)),
        const SizedBox(height: 12),
        const Text(
          'Practice Complete!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          lessonTitle,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        if (checkoutData.difficulty != 'n/a') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _capitalize(checkoutData.difficulty),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  final CheckoutData checkoutData;
  const _StatsCard({required this.checkoutData});

  @override
  Widget build(BuildContext context) {
    final correctCount = checkoutData.correctCount;
    final incorrectCount = checkoutData.totalCount - checkoutData.correctCount;
    return Container(
      width: double.infinity,
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
          _StatItem(value: '$correctCount', label: 'Correct', valueColor: AppColors.success),
          _StatItem(value: '$incorrectCount', label: 'Incorrect', valueColor: AppColors.error),
          _StatItem(value: '+${checkoutData.xpEarned}', label: 'XP', valueColor: AppColors.xpGold),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  const _StatItem({required this.value, required this.label, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: valueColor)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ],
    );
  }
}
