import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

const _kStreakGradientEnd = Color(0xFF3E6FD8);
const _kWeekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

String _isoDate(DateTime d) => d.toIso8601String().substring(0, 10);

// S-10 — Streak Page
class StreakScreen extends ConsumerWidget {
  const StreakScreen({super.key});

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
                  : _buildContent(user),
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
            onPressed: () => context.pop(),
          ),
          const Expanded(
            child: Text(
              'Streak',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildContent(UserModel user) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 8),
          _FlameHeroCard(currentStreak: user.currentStreak, longestStreak: user.longestStreak),
          const SizedBox(height: 20),
          _StreakGoalCard(
            currentStreak: user.currentStreak,
            streakGoalDays: user.streakGoalDays,
            streakGoalAchieved: user.streakGoalAchieved,
          ),
          const SizedBox(height: 16),
          _WeeklyCalendarCard(
            currentStreak: user.currentStreak,
            lastStreakDate: user.lastStreakDate,
          ),
          const SizedBox(height: 16),
          _MotivationSection(
            currentStreak: user.currentStreak,
            dailyGoalMinutes: user.dailyGoalMinutes,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _FlameHeroCard extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;
  const _FlameHeroCard({required this.currentStreak, required this.longestStreak});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, _kStreakGradientEnd],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 64)),
          Text(
            '$currentStreak',
            style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const Text('Day Streak', style: TextStyle(fontSize: 16, color: Colors.white70)),
          const SizedBox(height: 8),
          Text(
            'Longest: $longestStreak days',
            style: const TextStyle(fontSize: 13, color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

class _StreakGoalCard extends StatelessWidget {
  final int currentStreak;
  final int streakGoalDays;
  final bool streakGoalAchieved;

  const _StreakGoalCard({
    required this.currentStreak,
    required this.streakGoalDays,
    required this.streakGoalAchieved,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (currentStreak / streakGoalDays).clamp(0.0, 1.0);
    final daysToGo = (streakGoalDays - currentStreak).clamp(0, streakGoalDays);

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
            children: [
              const Text('Streak Goal',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const Spacer(),
              Text('$streakGoalDays days',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              color: streakGoalAchieved ? AppColors.success : AppColors.primary,
              backgroundColor: AppColors.primarySoft,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          if (streakGoalAchieved)
            const Text('✓ Goal achieved! 🎉',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success))
          else
            Text('$daysToGo days to go',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _WeeklyCalendarCard extends StatelessWidget {
  final int currentStreak;
  final String lastStreakDate;

  const _WeeklyCalendarCard({required this.currentStreak, required this.lastStreakDate});

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
          const Text('This Week',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                _DayCircle(
                  dayNumber: monday.add(Duration(days: i)).day,
                  weekdayLabel: _kWeekdayLabels[i],
                  isToday: _isoDate(monday.add(Duration(days: i))) == todayStr,
                  isActive: activeDays.contains(_isoDate(monday.add(Duration(days: i)))),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCircle extends StatelessWidget {
  final int dayNumber;
  final String weekdayLabel;
  final bool isToday;
  final bool isActive;

  const _DayCircle({
    required this.dayNumber,
    required this.weekdayLabel,
    required this.isToday,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    Color background;
    Color textColor;
    Border? border;

    if (isToday && isActive) {
      background = AppColors.primary;
      textColor = Colors.white;
      border = Border.all(color: AppColors.xpGold, width: 2);
    } else if (isToday) {
      background = AppColors.backgroundAccent;
      textColor = AppColors.textPrimary;
      border = Border.all(color: AppColors.primary, width: 2);
    } else if (isActive) {
      background = AppColors.primary;
      textColor = Colors.white;
    } else {
      background = AppColors.backgroundAccent;
      textColor = AppColors.textSecondary;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle, border: border),
          child: Text(
            '$dayNumber',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(weekdayLabel, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _MotivationSection extends StatelessWidget {
  final int currentStreak;
  final int dailyGoalMinutes;

  const _MotivationSection({required this.currentStreak, required this.dailyGoalMinutes});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Text(
            currentStreak == 0
                ? 'Start your streak today! Complete a lesson to begin.'
                : "Keep going! Don't break your streak.",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Daily goal: $dailyGoalMinutes min per day',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
