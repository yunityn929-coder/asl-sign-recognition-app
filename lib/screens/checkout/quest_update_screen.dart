import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../models/daily_quest_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quest_provider.dart';

// S-22 — Daily Quest Update
class QuestUpdateScreen extends ConsumerWidget {
  const QuestUpdateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    final daily = uid == null ? null : ref.watch(questStreamProvider(uid)).value;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildContent(daily)),
            _buildBottomButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quest Progress',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          SizedBox(height: 4),
          Text("Today's quests", style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildContent(DailyQuestModel? daily) {
    if (daily == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (daily.quests.isEmpty) {
      return const Center(
        child: Text('No active quests today', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final quest in daily.quests) _QuestCard(quest: quest),
        if (daily.bonusXpAwarded > 0) _BonusXpCard(bonusXp: daily.bonusXpAwarded),
      ],
    );
  }

  Widget _buildBottomButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => context.go(kRouteHome),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  final QuestModel quest;
  const _QuestCard({required this.quest});

  IconData get _icon {
    switch (quest.type) {
      case 'complete_lessons':
        return Icons.school_outlined;
      case 'earn_xp':
        return Icons.bolt_outlined;
      case 'practice_sessions':
        return Icons.fitness_center_outlined;
      default:
        return Icons.flag_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = quest.completed ? AppColors.primary : AppColors.textSecondary;
    final progressRatio = (quest.progress / quest.target).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quest.description,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('${quest.progress} / ${quest.target}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressRatio,
                    color: quest.completed ? AppColors.success : AppColors.primary,
                    backgroundColor: AppColors.primarySoft,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          if (quest.completed) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '✓ +${quest.xpReward} XP',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BonusXpCard extends StatelessWidget {
  final int bonusXp;
  const _BonusXpCard({required this.bonusXp});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.xpGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.xpGold),
      ),
      child: Row(
        children: [
          const Text('🌟', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bonus XP Claimed! +$bonusXp XP',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
