import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/route_constants.dart';
import 'firebase_options.dart';
import 'router.dart';
import 'screens/recognition_test/recognition_test_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Sign in silently so home screen has a real UID for Firestore reads.
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    try {
      await auth.signInAnonymously();
    } catch (_) {}
  }

  runApp(const ProviderScope(child: _HomeTestApp()));
}

// Temporary test app — boots directly into HomeScreen.
// Swap to HiAslApp() once full flow is verified end-to-end.
class _HomeTestApp extends StatelessWidget {
  const _HomeTestApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          surface: AppColors.backgroundPrimary,
        ),
        scaffoldBackgroundColor: AppColors.backgroundPrimary,
        useMaterial3: true,
      ),
      routerConfig: GoRouter(
        initialLocation: kRouteHome,
        routes: [
          GoRoute(
            path: kRouteHome,
            builder: (_, __) => const RecognitionTestScreen(),
          ),
          GoRoute(
            path: kRouteModeSelect,
            builder: (context, state) => Scaffold(
              appBar: AppBar(
                  title: Text('Mode: ${state.pathParameters['lessonId']}')),
              body: const Center(child: Text('Mode Select — TODO')),
            ),
          ),
          GoRoute(
            path: kRouteSettings,
            builder: (_, __) => const Scaffold(
              body: Center(child: Text('Settings — TODO')),
            ),
          ),
          GoRoute(
            path: kRouteStreak,
            builder: (_, __) => const Scaffold(
              body: Center(child: Text('Streak — TODO')),
            ),
          ),
        ],
      ),
    );
  }
}

class HiAslApp extends StatelessWidget {
  const HiAslApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'HiASL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          surface: AppColors.backgroundPrimary,
        ),
        scaffoldBackgroundColor: AppColors.backgroundPrimary,
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}
