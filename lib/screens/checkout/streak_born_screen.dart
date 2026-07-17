import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

const _kStreakGradientEnd = Color(0xFF3E6FD8);

// S-21 — Post-Checkout Streak Born / Extended
class StreakBornScreen extends ConsumerWidget {
  const StreakBornScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    final user = uid == null ? null : ref.watch(userProvider(uid)).value;
    final streak = user?.currentStreak ?? 0;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, _kStreakGradientEnd],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 16),
              const Text(
                'Streak Extended!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                '$streak',
                style: const TextStyle(
                    fontSize: 72, fontWeight: FontWeight.bold, color: AppColors.xpGold),
              ),
              const Text(
                'Day Streak',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _motivationalMessage(streak),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              const SizedBox(height: 48),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 32),
                child: ElevatedButton(
                  onPressed: () => context.go(kRouteSessionQuest),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Continue →',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _motivationalMessage(int streak) {
  if (streak <= 1) return "You've started your streak! Come back tomorrow!";
  if (streak <= 3) return 'Great start! Keep it up!';
  if (streak <= 7) return "You're building a habit!";
  if (streak <= 14) return 'Impressive dedication!';
  if (streak <= 29) return "You're on fire! 🔥";
  return "Unstoppable! You're a signing champion! 🏆";
}
