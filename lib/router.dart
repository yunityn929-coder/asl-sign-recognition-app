import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/route_constants.dart';
import 'core/navigation/app_shell.dart';
import 'data/quiz_definitions.dart';
import 'models/checkout_data.dart';

// Welcome
import 'screens/splash/splash_screen.dart';
import 'screens/welcome/welcome_brand_screen.dart';
import 'screens/welcome/welcome_preview_screen.dart';

// Onboarding
import 'screens/onboarding/onboarding_reason_screen.dart';
import 'screens/onboarding/onboarding_level_screen.dart';
import 'screens/onboarding/onboarding_goal_screen.dart';
import 'screens/onboarding/onboarding_notifications_screen.dart';

// Shell tabs
import 'screens/home/home_screen.dart';
import 'screens/quest/quest_screen.dart';
import 'screens/signs/signs_screen.dart';
import 'screens/profile/profile_screen.dart';

// Core screens
import 'screens/streak/streak_screen.dart';
import 'screens/mode_select/mode_select_screen.dart';
import 'screens/learn/learn_screen.dart';
import 'screens/practice/practice_setup_screen.dart';
import 'screens/practice/practice_session_screen.dart';

// Checkout flow
import 'screens/checkout/checkout_screen.dart';

// Post-session
import 'screens/completion/learn_completion_screen.dart';
import 'screens/medal/medal_reward_screen.dart';

// Lesson flow
import 'screens/lesson/exercise_screen.dart';
import 'screens/lesson/results_screen.dart';

// Quiz flow
import 'screens/quiz/quiz_screen.dart';
import 'screens/quiz/quiz_session_screen.dart';
import 'screens/quiz/quiz_result_screen.dart';

// Social / extras
import 'screens/settings/settings_screen.dart';
import 'screens/leaderboard/leaderboard_screen.dart';
import 'screens/social/link_account_screen.dart';
import 'screens/social/sign_in_screen.dart';

// Debug / diagnostics (not part of learner-facing flow)
import 'screens/debug/recognition_test_screen.dart';

// Calibration (optional per-user tuning, reached from Settings)
import 'screens/calibration/calibration_screen.dart';
import 'screens/settings/calibration_settings_screen.dart';

// Reminder (daily practice notification, reached from Settings)
import 'screens/settings/reminder_settings_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: kRouteSplash,
  //initialLocation: kRouteDebugRecognitionTest,
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

    // S-04 — Welcome: Questions Preview
    GoRoute(
      path: kRouteWelcomePreview,
      name: kRouteNameWelcomePreview,
      builder: (context, state) => const WelcomePreviewScreen(),
    ),

    // Onboarding: Reason (why learning ASL)
    GoRoute(
      path: kRouteOnboardingReason,
      name: kRouteNameOnboardingReason,
      builder: (context, state) => const OnboardingReasonScreen(),
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

    // Shell — persistent bottom nav for Home / Quiz / Signs / Profile
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: kRouteHome,
          name: kRouteNameHome,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: kRouteQuiz,
          name: kRouteNameQuiz,
          builder: (context, state) => const QuizScreen(),
        ),
        GoRoute(
          path: kRouteQuest,
          name: kRouteNameQuest,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? const {};
            return QuestScreen(justEarned: extra['justEarned'] as bool? ?? false);
          },
        ),
        GoRoute(
          path: kRouteSigns,
          name: kRouteNameSigns,
          builder: (context, state) => const SignsScreen(),
        ),
        GoRoute(
          path: kRouteProfile,
          name: kRouteNameProfile,
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),

    // S-14 — Streak Page
    GoRoute(
      path: kRouteStreak,
      name: kRouteNameStreak,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? const {};
        return StreakScreen(
          justEarned: extra['justEarned'] as bool? ?? false,
          skipQuestScreen: extra['skipQuestScreen'] as bool? ?? false,
        );
      },
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

    // Medal Reward — shown after Checkout when a practice session earns a
    // new medal, before continuing into the streak/quest/home chain.
    GoRoute(
      path: kRouteMedalReward,
      name: kRouteNameMedalReward,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? const {};
        return MedalRewardScreen(
          difficulty: extra['difficulty'] as String? ?? 'easy',
          nextRoute: extra['nextRoute'] as String? ?? kRouteHome,
          nextRouteExtra: extra['nextRouteExtra'] as Map<String, dynamic>?,
        );
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

    // S-25 — Google Sign-In: link current anonymous progress to a Google account
    GoRoute(
      path: kRouteLinkAccount,
      name: kRouteNameLinkAccount,
      builder: (context, state) => const LinkAccountScreen(),
    ),

    // S-25 — Google Sign-In: switch to a different existing account
    GoRoute(
      path: kRouteSignIn,
      name: kRouteNameSignIn,
      builder: (context, state) => const SignInScreen(),
    ),

    // S-15 — Lesson Exercise (root navigator so push/pop works outside the shell)
    GoRoute(
      path: kRouteLessonExercise,
      name: kRouteNameLessonExercise,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final lessonId = state.pathParameters['lessonId']!;
        return ExerciseScreen(lessonId: lessonId);
      },
    ),

    // S-16 — Lesson Results (root navigator so push/pop works outside the shell)
    GoRoute(
      path: kRouteLessonResults,
      name: kRouteNameLessonResults,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final lessonId = state.pathParameters['lessonId']!;
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return ResultsScreen(
          lessonId: lessonId,
          correctCount: extra['correctCount'] as int? ?? 0,
          totalCount: extra['totalCount'] as int? ?? 0,
          missedSigns:
              (extra['missedSigns'] as List?)?.cast<String>() ?? const [],
          learnAttempts:
              (extra['learnAttempts'] as Map?)?.cast<String, int>() ??
                  const {},
          streakJustExtended: extra['streakJustExtended'] as bool? ?? false,
          questNewlyCompleted: extra['questNewlyCompleted'] as bool? ?? false,
        );
      },
    ),

    // Quiz Session (root navigator so push/pop works outside the shell)
    GoRoute(
      path: kRouteQuizSession,
      name: kRouteNameQuizSession,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final quizSet = state.extra as QuizSet;
        return QuizSessionScreen(quizSet: quizSet);
      },
    ),

    // Quiz Result (root navigator so push/pop works outside the shell)
    GoRoute(
      path: kRouteQuizResult,
      name: kRouteNameQuizResult,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return QuizResultScreen(
          score: extra['score'] as int? ?? 0,
          total: extra['total'] as int? ?? 0,
          quizSet: extra['quizSet'] as QuizSet,
          wrongSigns: (extra['wrongSigns'] as List?)?.cast<String>() ?? const [],
          streakJustExtended: extra['streakJustExtended'] as bool? ?? false,
          questNewlyCompleted: extra['questNewlyCompleted'] as bool? ?? false,
        );
      },
    ),

    // Debug — physical-device recognition testing (kDebugMode-gated entry
    // point in Settings; see docs/GESTURE_TESTING_PROTOCOL.md)
    GoRoute(
      path: kRouteDebugRecognitionTest,
      name: kRouteNameDebugRecognitionTest,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RecognitionTestScreen(),
    ),

    // Calibration — optional per-user sign calibration (entry point in
    // Settings: "Calibrate my signs").
    GoRoute(
      path: kRouteCalibration,
      name: kRouteNameCalibration,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CalibrationScreen(),
    ),

    // Calibration settings — toggle + entry point for the calibration flow
    // above (reached from Settings: "Calibrate my signs").
    GoRoute(
      path: kRouteCalibrationSettings,
      name: kRouteNameCalibrationSettings,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CalibrationSettingsScreen(),
    ),

    // Reminder settings — daily practice notification toggle + time picker
    // (reached from Settings: "Practice Reminder").
    GoRoute(
      path: kRouteReminderSettings,
      name: kRouteNameReminderSettings,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ReminderSettingsScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('Route not found: ${state.uri}')),
  ),
);
