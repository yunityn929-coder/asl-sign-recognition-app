import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// S-05 — Onboarding Q2: Daily Goal
class OnboardingGoalScreen extends ConsumerWidget {
  const OnboardingGoalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(child: Text('Onboarding: Daily Goal — TODO')),
    );
  }
}
