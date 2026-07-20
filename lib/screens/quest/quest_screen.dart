import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../models/daily_quest_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quest_provider.dart';

class QuestScreen extends ConsumerStatefulWidget {
  final bool justEarned;
  const QuestScreen({super.key, this.justEarned = false});

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
      data: (daily) => daily == null
          ? const _LoadingQuests()
          : _QuestList(daily: daily, animate: widget.justEarned),
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
  final bool animate;
  const _QuestList({required this.daily, this.animate = false});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Daily Quests',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: -0.3,
            ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatResetIn(DateTime.now()),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        for (final quest in daily.quests) ...[
          _QuestCard(quest: quest, animate: animate),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _QuestCard extends StatelessWidget {
  final QuestModel quest;
  final bool animate;
  const _QuestCard({required this.quest, this.animate = false});

  @override
  Widget build(BuildContext context) {
    final progress = quest.target == 0
        ? 0.0
        : (quest.progress / quest.target).clamp(0.0, 1.0);

    final progressBar = animate
        ? TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: AppColors.primarySoft,
              color: quest.completed ? AppColors.success : AppColors.primary,
            ),
          )
        : LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.primarySoft,
            color: quest.completed ? AppColors.success : AppColors.primary,
          );

    final xpBadge = Text(
      '+${quest.xpReward} XP',
      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.xpGold),
    );

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
                    child: progressBar,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (animate && quest.completed)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: xpBadge,
              )
            else
              xpBadge,
          ],
        ),
      ),
    );
  }
}

String _formatResetIn(DateTime now) {
  final nextMidnight = DateTime(now.year, now.month, now.day + 1);
  final hoursLeft = (nextMidnight.difference(now).inMinutes / 60).ceil();
  return 'Resets in $hoursLeft ${hoursLeft == 1 ? 'hour' : 'hours'}';
}
