import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_constants.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

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
      FlutterNativeSplash.remove();
      context.go(kRouteWelcomeBrand);
      return;
    }
    if (!mounted) return;

    try {
      await firestoreService.createUser(uid);
      var userModel = await firestoreService.getUserOnce(uid);
      if (!mounted) return;

      // Self-heal: Firebase Auth can already be linked while the Firestore
      // doc's isAnonymous flag never caught up. Backfill it here so the
      // account isn't stuck showing guest state with no way to sign out.
      final authUser = authService.currentUser;
      if (authUser != null && !authUser.isAnonymous && (userModel?.isAnonymous ?? true)) {
        // Top-level User.displayName/photoURL/email aren't reliably
        // populated by linkWithCredential() — the real data is on the
        // provider-specific entry in providerData.
        final googleProviders =
            authUser.providerData.where((p) => p.providerId == 'google.com');
        final googleInfo = googleProviders.isEmpty ? null : googleProviders.first;
        try {
          await firestoreService.updateUser(uid, {
            'isAnonymous': false,
            'authProvider': googleInfo != null ? 'google' : (userModel?.authProvider ?? 'google'),
            'displayName': googleInfo?.displayName ?? authUser.displayName ?? userModel?.displayName ?? 'Learner',
            'email': googleInfo?.email ?? authUser.email ?? userModel?.email ?? '',
            'photoUrl': googleInfo?.photoURL ?? authUser.photoURL ?? userModel?.photoUrl ?? '',
          });
          userModel = await firestoreService.getUserOnce(uid);
        } catch (e) {
          debugPrint('[SplashScreen] account-link reconciliation failed: $e');
        }
        if (!mounted) return;
      }

      final onboardingComplete = userModel?.onboardingComplete ?? false;
      FlutterNativeSplash.remove();
      context.go(onboardingComplete ? kRouteHome : kRouteWelcomeBrand);
    } catch (e) {
      debugPrint('[SplashScreen] user doc init/read error: $e');
      if (!mounted) return;
      FlutterNativeSplash.remove();
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
