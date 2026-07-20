import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

const _kWeekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

String _isoDate(DateTime d) => d.toIso8601String().substring(0, 10);

// S-10 — Streak Page
class StreakScreen extends ConsumerWidget {
  final bool justEarned;
  final bool skipQuestScreen;
  const StreakScreen({
    super.key,
    this.justEarned = false,
    this.skipQuestScreen = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    final user = uid == null ? null : ref.watch(userProvider(uid)).value;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: user == null
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContent(context, user),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => context.go(kRouteHome),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, UserModel user) {
    return Column(
      children: [
        const Spacer(),
        _FlameHeroCard(currentStreak: user.currentStreak),
        const SizedBox(height: 32),
        _WeeklyCalendarCard(
          currentStreak: user.currentStreak,
          lastStreakDate: user.lastStreakDate,
          animateToday: justEarned,
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go(
                  justEarned && !skipQuestScreen ? kRouteQuest : kRouteHome),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text("Let's go",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ),
      ],
    );
  }
}

class _FlameHeroCard extends StatelessWidget {
  final int currentStreak;
  const _FlameHeroCard({required this.currentStreak});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset('assets/images/owl_streak.png', width: 240, height: 240),
        const SizedBox(height: 8),
        Text(
          '$currentStreak',
          style: const TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w900,
            color: Color(0xFFFFA757),
            letterSpacing: -1,
          ),
        ),
        const Text(
          'day streak',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF38963)),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            currentStreak == 0
                ? 'Start your streak today! Complete a lesson to begin.'
                : "Keep going! Don't break your streak.",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _WeeklyCalendarCard extends StatelessWidget {
  final int currentStreak;
  final String lastStreakDate;
  final bool animateToday;

  const _WeeklyCalendarCard({
    required this.currentStreak,
    required this.lastStreakDate,
    this.animateToday = false,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStr = _isoDate(today);
    final lastDate = DateTime.tryParse(lastStreakDate) ?? today;

    final activeDays = <String>{
      for (var i = 0; i < currentStreak; i++) _isoDate(lastDate.subtract(Duration(days: i))),
    };

    final monday = today.subtract(Duration(days: today.weekday - 1));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                _DayCircle(
                  weekdayLabel: _kWeekdayLabels[i],
                  isToday: _isoDate(monday.add(Duration(days: i))) == todayStr,
                  isActive: activeDays.contains(_isoDate(monday.add(Duration(days: i)))),
                  animate: animateToday &&
                      _isoDate(monday.add(Duration(days: i))) == todayStr,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCircle extends StatelessWidget {
  final String weekdayLabel;
  final bool isToday;
  final bool isActive;
  final bool animate;

  const _DayCircle({
    required this.weekdayLabel,
    required this.isToday,
    required this.isActive,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    Border? border;
    if (isToday && isActive) {
      border = Border.all(color: AppColors.xpGold, width: 2);
    } else if (isToday) {
      border = Border.all(color: AppColors.primary, width: 2);
    } else if (!isActive) {
      border = Border.all(color: AppColors.primarySoft, width: 1.5);
    }

    final circle = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : Colors.transparent,
        shape: BoxShape.circle,
        border: border,
      ),
      child: isActive
          ? const Icon(Icons.local_fire_department_rounded, size: 18, color: Colors.white)
          : null,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          weekdayLabel,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        if (animate)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, value, child) => Transform.scale(scale: value, child: child),
            child: circle,
          )
        else
          circle,
      ],
    );
  }
}
