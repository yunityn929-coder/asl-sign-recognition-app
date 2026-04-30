import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// S-07 — Onboarding Q4: Starting Point
class OnboardingStartScreen extends ConsumerWidget {
  const OnboardingStartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(child: Text('Onboarding: Starting Point — TODO')),
    );
  }
}
