import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/xp_constants.dart';
import '../../models/daily_quest_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quest_provider.dart';

class QuestScreen extends ConsumerStatefulWidget {
  const QuestScreen({super.key});

  @override
  ConsumerState<QuestScreen> createState() => _QuestScreenState();
}

class _QuestScreenState extends ConsumerState<QuestScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(authStateProvider).value?.uid;
      if (uid != null) ref.read(dailyQuestProvider(uid));
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).value?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: uid == null
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(uid),
      ),
    );
  }

  Widget _buildBody(String uid) {
    final questsAsync = ref.watch(questStreamProvider(uid));

    return questsAsync.when(
      data: (daily) =>
          daily == null ? const _LoadingQuests() : _QuestList(daily: daily),
      loading: () => const _LoadingQuests(),
      error: (_, __) => const Center(
        child: Text('Failed to load quests. Pull to refresh.'),
      ),
    );
  }
}

class _LoadingQuests extends StatelessWidget {
  const _LoadingQuests();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading your daily quests...',
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _QuestList extends StatelessWidget {
  final DailyQuestModel daily;
  const _QuestList({required this.daily});

  @override
  Widget build(BuildContext context) {
    final bonusClaimed = daily.bonusXpAwarded > 0;
    final bonusAmount = kXpQuestBonus * daily.quests.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Daily Quests',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Complete quests to earn bonus XP',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          _formatDate(DateTime.now()),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        _BonusBanner(claimed: bonusClaimed, amount: bonusAmount),
        const SizedBox(height: 20),
        for (final quest in daily.quests) ...[
          _QuestCard(quest: quest),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _BonusBanner extends StatelessWidget {
  final bool claimed;
  final int amount;
  const _BonusBanner({required this.claimed, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.xpGold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.xpGold),
      ),
      child: Row(
        children: [
          const Text('⭐', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete all 3 quests for +$amount XP!',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                if (claimed) ...[
                  const SizedBox(height: 4),
                  const Text(
                    '✓ Bonus XP claimed!',
                    style: TextStyle(
                        color: AppColors.success, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ],
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
    final progress = quest.target == 0
        ? 0.0
        : (quest.progress / quest.target).clamp(0.0, 1.0);

    return Opacity(
      opacity: quest.completed ? 0.6 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primarySoft),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          quest.description,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                      ),
                      if (quest.completed)
                        const Icon(Icons.check_circle,
                            color: AppColors.success, size: 20),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Progress: ${quest.progress} / ${quest.target}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: AppColors.primarySoft,
                      color:
                          quest.completed ? AppColors.success : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '+${quest.xpReward} XP',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.xpGold),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
}
