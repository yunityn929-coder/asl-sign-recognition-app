import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../models/daily_quest_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quest_provider.dart';
import '../../services/firestore_service.dart';

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

  Future<bool> _collect(String uid, String questId) {
    return ref.read(firestoreServiceProvider).collectQuestReward(uid, questId);
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
          : _QuestList(
              daily: daily,
              animate: widget.justEarned,
              onCollect: (questId) => _collect(uid, questId),
            ),
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
  final Future<bool> Function(String questId) onCollect;
  const _QuestList({required this.daily, required this.onCollect, this.animate = false});

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
          _QuestCard(quest: quest, animate: animate, onCollect: onCollect),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _QuestCard extends StatelessWidget {
  final QuestModel quest;
  final bool animate;
  final Future<bool> Function(String questId) onCollect;
  const _QuestCard({required this.quest, required this.onCollect, this.animate = false});

  @override
  Widget build(BuildContext context) {
    final progress =
        quest.target == 0 ? 0.0 : (quest.progress / quest.target).clamp(0.0, 1.0);

    return Container(
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
                Text(
                  quest.description,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _QuestProgressBar(
                        progress: progress,
                        quest: quest,
                        animate: animate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ChestButton(
                      completed: quest.completed,
                      collected: quest.collected,
                      xpReward: quest.xpReward,
                      onCollect: () => onCollect(quest.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestProgressBar extends StatelessWidget {
  final double progress;
  final QuestModel quest;
  final bool animate;
  const _QuestProgressBar({
    required this.progress,
    required this.quest,
    this.animate = false,
  });

  Widget _fillBar(double value) {
    final clamped = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: SizedBox(
        height: 22,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(
              child: ColoredBox(color: AppColors.primarySoft),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: clamped == 0 ? 0.0001 : clamped,
                  heightFactor: 1.0,
                  child: const ColoredBox(color: AppColors.xpGold),
                ),
              ),
            ),
            Text(
              _progressLabel(quest),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!animate) return _fillBar(progress);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => _fillBar(value),
    );
  }
}

// The "collect" button: a treasure chest that is muted and inert while the
// quest is in progress, gains a red "ready" dot once completed, and turns
// into a dimmed checkmark once the reward has been claimed.
class _ChestButton extends StatefulWidget {
  final bool completed;
  final bool collected;
  final int xpReward;
  final Future<bool> Function() onCollect;
  const _ChestButton({
    required this.completed,
    required this.collected,
    required this.xpReward,
    required this.onCollect,
  });

  @override
  State<_ChestButton> createState() => _ChestButtonState();
}

class _ChestButtonState extends State<_ChestButton> {
  bool _busy = false;

  bool get _ready => widget.completed && !widget.collected;

  Future<void> _handleTap() async {
    if (_busy || !_ready) return;
    setState(() => _busy = true);
    bool collected = false;
    try {
      collected = await widget.onCollect();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (collected && mounted) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.emoji_events_rounded, color: AppColors.xpGold, size: 30),
          title: const Text('Reward Collected!'),
          content: Text('+${widget.xpReward} XP'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Nice!'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.collected
        ? const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 30)
        : Opacity(
            opacity: widget.completed ? 1.0 : 0.4,
            child: Image.asset('assets/images/treasure.png', width: 32, height: 32),
          );

    return GestureDetector(
      onTap: _ready ? _handleTap : null,
      child: AnimatedScale(
        scale: _busy ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            icon,
            if (_ready)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// 'spend_minutes' tracks progress/target in seconds internally (so short
// sessions still accumulate precisely) but reads as whole minutes here.
String _progressLabel(QuestModel quest) {
  if (quest.type == 'spend_minutes') {
    final current = (quest.progress / 60).floor();
    final target = (quest.target / 60).round();
    return '$current/$target min';
  }
  return '${quest.progress}/${quest.target}';
}

String _formatResetIn(DateTime now) {
  final nextMidnight = DateTime(now.year, now.month, now.day + 1);
  final hoursLeft = (nextMidnight.difference(now).inMinutes / 60).ceil();
  return 'Resets in $hoursLeft ${hoursLeft == 1 ? 'hour' : 'hours'}';
}
