import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';

class _MedalSpec {
  final String label;
  final Color color;
  const _MedalSpec(this.label, this.color);
}

const Map<String, _MedalSpec> _kMedalSpecs = {
  'easy': _MedalSpec('Bronze Medal', AppColors.medalBronze),
  'medium': _MedalSpec('Silver Medal', AppColors.medalSilver),
  'hard': _MedalSpec('Gold Medal', AppColors.medalGold),
};

// Post-checkout — Medal Reward
class MedalRewardScreen extends StatelessWidget {
  final String difficulty;
  final String nextRoute;
  final Map<String, dynamic>? nextRouteExtra;

  const MedalRewardScreen({
    required this.difficulty,
    required this.nextRoute,
    this.nextRouteExtra,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final spec = _kMedalSpecs[difficulty] ?? _kMedalSpecs['easy']!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/treasure.png', width: 200, height: 200),
                    const SizedBox(height: 16),
                    _MedalBadge(color: spec.color),
                    const SizedBox(height: 24),
                    Text(
                      '${spec.label} Earned!',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: spec.color,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'You got every sign right in this practice session!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go(nextRoute, extra: nextRouteExtra),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: spec.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Continue',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedalBadge extends StatelessWidget {
  final Color color;
  const _MedalBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 48),
    );
  }
}
