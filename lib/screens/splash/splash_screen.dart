import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_constants.dart';

// S-01 — Splash / Auth Gate
// Shows logo for ~1.5s, then:
//   - no user         → /login
//   - user, no onboarding → /onboarding/level
//   - user, onboarding done → /home
// TODO (Feature 2+): replace _checkOnboarding() body with FirestoreService call
//   so onboardingComplete is read from Firestore, not hardcoded to false.

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      context.go(kRouteLogin);
      return;
    }

    final onboardingComplete = await _checkOnboarding(user.uid);
    if (!mounted) return;

    context.go(onboardingComplete ? kRouteHome : kRouteOnboardingLevel);
  }

  // Returns false until FirestoreService is wired in Feature 2.
  Future<bool> _checkOnboarding(String uid) async {
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'HiASL',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
