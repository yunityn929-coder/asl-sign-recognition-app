import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_constants.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

// S-01 — Splash
// 1. Show logo ~1.5s
// 2. AuthService.signInSilently()
// 3. FirestoreService.createUser() if first launch
// 4. Read onboardingComplete → route to /welcome/brand or /home
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final authService = ref.read(authServiceProvider);
    final firestoreService = ref.read(firestoreServiceProvider);

    late String uid;
    try {
      final user = await authService.signInSilently();
      uid = user.uid;
    } catch (_) {
      if (!mounted) return;
      context.go(kRouteWelcomeBrand);
      return;
    }
    if (!mounted) return;

    try {
      await firestoreService.createUser(uid);
      final userModel = await firestoreService.getUserOnce(uid);
      if (!mounted) return;
      final onboardingComplete = userModel?.onboardingComplete ?? false;
      context.go(onboardingComplete ? kRouteHome : kRouteWelcomeBrand);
    } catch (e) {
      debugPrint('[SplashScreen] user doc init/read error: $e');
      if (!mounted) return;
      context.go(kRouteWelcomeBrand);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('HiASL', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
