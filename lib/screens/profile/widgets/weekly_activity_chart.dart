import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

// Displays combined active minutes (lessons + practice + quiz) for the
// current calendar week (Monday-start, matching the streak screen's week
// convention). Reads from UserModel.dailyActiveSeconds, a date-keyed map
// fed by the same per-session duration timer used for the daily
// 'spend_minutes' quest — see FirestoreService.recordDailyActiveSeconds.
class WeeklyActivityChart extends StatelessWidget {
  const WeeklyActivityChart({required this.dailyActiveSeconds, super.key});

  final Map<String, int> dailyActiveSeconds;

  static const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const double _chartHeight = 96;
  static const double _emptyBarFactor = 0.02;

  String _isoDate(DateTime d) => d.toIso8601String().substring(0, 10);

  // "45m" under an hour, "1h 12m" (or "1h" on the hour) at/above 60 minutes.
  static String _formatMinutes(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final todayStr = _isoDate(today);

    final weekDates = [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];
    final minutesByDay = [
      for (final d in weekDates) ((dailyActiveSeconds[_isoDate(d)] ?? 0) / 60).round(),
    ];
    final maxMinutes = minutesByDay.reduce((a, b) => a > b ? a : b);
    // Averaged over all 7 days (not just days with data) so this reads as
    // "your typical day this week", including rest days as zeros.
    final averageMinutes =
        (minutesByDay.reduce((a, b) => a + b) / minutesByDay.length).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Average Active Minutes',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatMinutes(averageMinutes),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: _chartHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _DayBar(
                      minutes: minutesByDay[i],
                      maxMinutes: maxMinutes,
                      isToday: _isoDate(weekDates[i]) == todayStr,
                      emptyBarFactor: _emptyBarFactor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Text(
                    _weekdayLabels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          _isoDate(weekDates[i]) == todayStr ? FontWeight.w800 : FontWeight.w600,
                      color: _isoDate(weekDates[i]) == todayStr
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.minutes,
    required this.maxMinutes,
    required this.isToday,
    required this.emptyBarFactor,
  });

  final int minutes;
  final int maxMinutes;
  final bool isToday;
  final double emptyBarFactor;

  @override
  Widget build(BuildContext context) {
    final heightFactor = maxMinutes == 0
        ? emptyBarFactor
        : (minutes == 0 ? emptyBarFactor : (minutes / maxMinutes).clamp(0.08, 1.0));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '$minutes',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isToday ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: heightFactor,
                child: Container(
                  decoration: BoxDecoration(
                    color: isToday ? AppColors.primary : AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
