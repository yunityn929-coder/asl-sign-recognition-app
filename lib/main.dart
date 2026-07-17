import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/route_constants.dart';
import 'core/navigation/app_shell.dart';
import 'firebase_options.dart';
import 'router.dart';
import 'screens/home/home_screen.dart';
import 'screens/lesson/exercise_screen.dart';
import 'screens/lesson/results_screen.dart';
import 'screens/quest/quest_screen.dart';
import 'screens/signs/signs_screen.dart';
import 'screens/profile/profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Ensure anonymous auth resolves before the first frame so authStateChanges()
  // emits a non-null user immediately and HomeScreen never shows a permanent spinner.
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    try {
      await auth.signInAnonymously();
    } catch (_) {}
  }

  runApp(const ProviderScope(child: _HomeTestApp()));
}

// Temporary test app — boots directly into HomeScreen with bottom nav shell.
// Swap to HiAslApp() once full flow is verified end-to-end.
final _testRootKey = GlobalKey<NavigatorState>();

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
        navigatorKey: _testRootKey,
        initialLocation: kRouteHome,
        routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(
                path: kRouteHome,
                builder: (_, __) => const HomeScreen(),
              ),
              GoRoute(
                path: kRouteQuest,
                builder: (_, __) => const QuestScreen(),
              ),
              GoRoute(
                path: kRouteSigns,
                builder: (_, __) => const SignsScreen(),
              ),
              GoRoute(
                path: kRouteProfile,
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
          GoRoute(
            path: kRouteLessonExercise,
            parentNavigatorKey: _testRootKey,
            builder: (context, state) {
              final lessonId = state.pathParameters['lessonId']!;
              return ExerciseScreen(lessonId: lessonId);
            },
          ),
          GoRoute(
            path: kRouteLessonResults,
            parentNavigatorKey: _testRootKey,
            builder: (context, state) {
              final lessonId = state.pathParameters['lessonId']!;
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return ResultsScreen(
                lessonId: lessonId,
                correctCount: extra['correctCount'] as int? ?? 0,
                totalCount: extra['totalCount'] as int? ?? 0,
                missedSigns:
                    (extra['missedSigns'] as List?)?.cast<String>() ?? const [],
              );
            },
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
