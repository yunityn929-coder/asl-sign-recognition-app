import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/route_constants.dart';
import 'models/checkout_data.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/onboarding_level_screen.dart';
import 'screens/onboarding/onboarding_goal_screen.dart';
import 'screens/onboarding/onboarding_notifications_screen.dart';
import 'screens/onboarding/onboarding_start_screen.dart';
import 'screens/onboarding/placement_test_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/streak/streak_screen.dart';
import 'screens/mode_select/mode_select_screen.dart';
import 'screens/learn/learn_screen.dart';
import 'screens/practice/practice_setup_screen.dart';
import 'screens/practice/practice_session_screen.dart';
import 'screens/checkout/checkout_screen.dart';
import 'screens/completion/learn_completion_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/auth/register_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: kRouteSplash,
  routes: [
    GoRoute(
      path: kRouteSplash,
      name: kRouteNameSplash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: kRouteLogin,
      name: kRouteNameLogin,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: kRouteOnboardingLevel,
      name: kRouteNameOnboardingLevel,
      builder: (context, state) => const OnboardingLevelScreen(),
    ),
    GoRoute(
      path: kRouteOnboardingGoal,
      name: kRouteNameOnboardingGoal,
      builder: (context, state) => const OnboardingGoalScreen(),
    ),
    GoRoute(
      path: kRouteOnboardingNotifications,
      name: kRouteNameOnboardingNotifications,
      builder: (context, state) => const OnboardingNotificationsScreen(),
    ),
    GoRoute(
      path: kRouteOnboardingStart,
      name: kRouteNameOnboardingStart,
      builder: (context, state) => const OnboardingStartScreen(),
    ),
    GoRoute(
      path: kRouteOnboardingPlacement,
      name: kRouteNameOnboardingPlacement,
      builder: (context, state) => const PlacementTestScreen(),
    ),
    GoRoute(
      path: kRouteHome,
      name: kRouteNameHome,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: kRouteStreak,
      name: kRouteNameStreak,
      builder: (context, state) => const StreakScreen(),
    ),
    GoRoute(
      path: '/lesson/:lessonId/mode',
      name: kRouteNameModeSelect,
      builder: (context, state) {
        final lessonId = state.pathParameters['lessonId']!;
        return ModeSelectScreen(lessonId: lessonId);
      },
    ),
    GoRoute(
      path: '/lesson/:lessonId/learn',
      name: kRouteNameLearn,
      builder: (context, state) {
        final lessonId = state.pathParameters['lessonId']!;
        return LearnScreen(lessonId: lessonId);
      },
    ),
    GoRoute(
      path: '/lesson/:lessonId/practice/setup',
      name: kRouteNamePracticeSetup,
      builder: (context, state) {
        final lessonId = state.pathParameters['lessonId']!;
        return PracticeSetupScreen(lessonId: lessonId);
      },
    ),
    GoRoute(
      path: '/lesson/:lessonId/practice/session',
      name: kRouteNamePracticeSession,
      builder: (context, state) {
        final lessonId = state.pathParameters['lessonId']!;
        final difficulty = state.extra as String? ?? 'easy';
        return PracticeSessionScreen(lessonId: lessonId, difficulty: difficulty);
      },
    ),
    GoRoute(
      path: kRouteCheckout,
      name: kRouteNameCheckout,
      builder: (context, state) {
        final data = state.extra as CheckoutData;
        return CheckoutScreen(checkoutData: data);
      },
    ),
    GoRoute(
      path: '/lesson/:lessonId/complete',
      name: kRouteNameLearnComplete,
      builder: (context, state) {
        final lessonId = state.pathParameters['lessonId']!;
        return LearnCompletionScreen(lessonId: lessonId);
      },
    ),
    GoRoute(
      path: kRouteSettings,
      name: kRouteNameSettings,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: kRouteConvertGuest,
      name: kRouteNameConvertGuest,
      builder: (context, state) => const RegisterScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('Route not found: ${state.uri}')),
  ),
);
