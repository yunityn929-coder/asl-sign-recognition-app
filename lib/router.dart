import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/route_constants.dart';
import 'models/checkout_data.dart';

// Welcome
import 'screens/splash/splash_screen.dart';
import 'screens/welcome/welcome_brand_screen.dart';
import 'screens/welcome/welcome_intro_screen.dart';
import 'screens/welcome/welcome_preview_screen.dart';

// Onboarding
import 'screens/onboarding/onboarding_level_screen.dart';
import 'screens/onboarding/onboarding_goal_screen.dart';
import 'screens/onboarding/onboarding_notifications_screen.dart';
import 'screens/onboarding/onboarding_achievement_screen.dart';
import 'screens/onboarding/onboarding_start_screen.dart';
import 'screens/onboarding/placement_test_screen.dart';
import 'screens/onboarding/placement_result_screen.dart';
import 'screens/onboarding/streak_goal_screen.dart';

// Core screens
import 'screens/home/home_screen.dart';
import 'screens/streak/streak_screen.dart';
import 'screens/mode_select/mode_select_screen.dart';
import 'screens/learn/learn_screen.dart';
import 'screens/practice/practice_setup_screen.dart';
import 'screens/practice/practice_session_screen.dart';

// Checkout flow
import 'screens/checkout/checkout_screen.dart';
import 'screens/checkout/streak_born_screen.dart';
import 'screens/checkout/quest_update_screen.dart';

// Post-session
import 'screens/completion/learn_completion_screen.dart';

// Social / extras
import 'screens/settings/settings_screen.dart';
import 'screens/leaderboard/leaderboard_screen.dart';
import 'screens/social/social_sign_in_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: kRouteSplash,
  routes: [
    // S-01 — Splash
    GoRoute(
      path: kRouteSplash,
      name: kRouteNameSplash,
      builder: (context, state) => const SplashScreen(),
    ),

    // S-02 — Welcome: Brand
    GoRoute(
      path: kRouteWelcomeBrand,
      name: kRouteNameWelcomeBrand,
      builder: (context, state) => const WelcomeBrandScreen(),
    ),

    // S-03 — Welcome: Mascot Intro
    GoRoute(
      path: kRouteWelcomeIntro,
      name: kRouteNameWelcomeIntro,
      builder: (context, state) => const WelcomeIntroScreen(),
    ),

    // S-04 — Welcome: Questions Preview
    GoRoute(
      path: kRouteWelcomePreview,
      name: kRouteNameWelcomePreview,
      builder: (context, state) => const WelcomePreviewScreen(),
    ),

    // S-05 — Onboarding Q1: ASL Level
    GoRoute(
      path: kRouteOnboardingLevel,
      name: kRouteNameOnboardingLevel,
      builder: (context, state) => const OnboardingLevelScreen(),
    ),

    // S-06 — Onboarding Q2: Daily Goal
    GoRoute(
      path: kRouteOnboardingGoal,
      name: kRouteNameOnboardingGoal,
      builder: (context, state) => const OnboardingGoalScreen(),
    ),

    // S-07 — Onboarding Q3: Notifications
    GoRoute(
      path: kRouteOnboardingNotifications,
      name: kRouteNameOnboardingNotifications,
      builder: (context, state) => const OnboardingNotificationsScreen(),
    ),

    // S-08 — Onboarding: Achievement Preview
    GoRoute(
      path: kRouteOnboardingAchievement,
      name: kRouteNameOnboardingAchievement,
      builder: (context, state) => const OnboardingAchievementScreen(),
    ),

    // S-09 — Onboarding Q4: Starting Point
    GoRoute(
      path: kRouteOnboardingStart,
      name: kRouteNameOnboardingStart,
      builder: (context, state) => const OnboardingStartScreen(),
    ),

    // S-10 — Placement Test
    GoRoute(
      path: kRouteOnboardingPlacement,
      name: kRouteNameOnboardingPlacement,
      builder: (context, state) => const PlacementTestScreen(),
    ),

    // S-11 — Placement Result (extra: Map<String, dynamic> with startLessonId + correctCount)
    GoRoute(
      path: kRouteOnboardingPlacementResult,
      name: kRouteNameOnboardingPlacementResult,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>? ?? {};
        return PlacementResultScreen(
          startLessonId: data['startLessonId'] as String? ?? 's1l1',
          correctCount: data['correctCount'] as int? ?? 0,
        );
      },
    ),

    // S-12 — Streak Goal Selection (extra: String startLessonId)
    GoRoute(
      path: kRouteOnboardingStreakGoal,
      name: kRouteNameOnboardingStreakGoal,
      builder: (context, state) {
        final startLessonId = state.extra as String? ?? 's1l1';
        return StreakGoalScreen(startLessonId: startLessonId);
      },
    ),

    // S-13 — Home
    GoRoute(
      path: kRouteHome,
      name: kRouteNameHome,
      builder: (context, state) => const HomeScreen(),
    ),

    // S-14 — Streak Page
    GoRoute(
      path: kRouteStreak,
      name: kRouteNameStreak,
      builder: (context, state) => const StreakScreen(),
    ),

    // S-15 — Mode Select
    GoRoute(
      path: kRouteModeSelect,
      name: kRouteNameModeSelect,
      builder: (context, state) {
        final lessonId = state.pathParameters['lessonId']!;
        return ModeSelectScreen(lessonId: lessonId);
      },
    ),

    // S-16 — Learn Session
    GoRoute(
      path: kRouteLearn,
      name: kRouteNameLearn,
      builder: (context, state) {
        final lessonId = state.pathParameters['lessonId']!;
        return LearnScreen(lessonId: lessonId);
      },
    ),

    // S-17 — Practice Setup
    GoRoute(
      path: kRoutePracticeSetup,
      name: kRouteNamePracticeSetup,
      builder: (context, state) {
        final lessonId = state.pathParameters['lessonId']!;
        return PracticeSetupScreen(lessonId: lessonId);
      },
    ),

    // S-18 — Practice Session
    GoRoute(
      path: kRoutePracticeSession,
      name: kRouteNamePracticeSession,
      builder: (context, state) {
        final lessonId = state.pathParameters['lessonId']!;
        final difficulty = state.extra as String? ?? 'easy';
        return PracticeSessionScreen(lessonId: lessonId, difficulty: difficulty);
      },
    ),

    // S-19 — Session Checkout
    GoRoute(
      path: kRouteCheckout,
      name: kRouteNameCheckout,
      builder: (context, state) {
        final data = state.extra as CheckoutData;
        return CheckoutScreen(checkoutData: data);
      },
    ),

    // S-20 — Learn Completion
    GoRoute(
      path: kRouteLearnComplete,
      name: kRouteNameLearnComplete,
      builder: (context, state) {
        final lessonId = state.pathParameters['lessonId']!;
        return LearnCompletionScreen(lessonId: lessonId);
      },
    ),

    // S-21 — Post-Checkout Streak Born
    GoRoute(
      path: kRouteSessionStreak,
      name: kRouteNameSessionStreak,
      builder: (context, state) => const StreakBornScreen(),
    ),

    // S-22 — Daily Quest Update
    GoRoute(
      path: kRouteSessionQuest,
      name: kRouteNameSessionQuest,
      builder: (context, state) => const QuestUpdateScreen(),
    ),

    // S-23 — Settings
    GoRoute(
      path: kRouteSettings,
      name: kRouteNameSettings,
      builder: (context, state) => const SettingsScreen(),
    ),

    // S-24 — Leaderboard (login-gated)
    GoRoute(
      path: kRouteLeaderboard,
      name: kRouteNameLeaderboard,
      builder: (context, state) => const LeaderboardScreen(),
    ),

    // S-25 — Google Sign-In (social unlock)
    GoRoute(
      path: kRouteSocialSignIn,
      name: kRouteNameSocialSignIn,
      builder: (context, state) => const SocialSignInScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('Route not found: ${state.uri}')),
  ),
);
