import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/onboarding_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/mascot_image.dart';
import '../../widgets/progress_step_indicator.dart';
import '../../widgets/speech_bubble.dart';

// S-07 — Onboarding Q3: Notifications
class OnboardingNotificationsScreen extends ConsumerStatefulWidget {
  const OnboardingNotificationsScreen({super.key});

  @override
  ConsumerState<OnboardingNotificationsScreen> createState() =>
      _OnboardingNotificationsScreenState();
}

class _OnboardingNotificationsScreenState
    extends ConsumerState<OnboardingNotificationsScreen> {
  bool _loading = false;

  Future<void> _onRemind() async {
    setState(() => _loading = true);
    bool granted = false;
    try {
      granted = await ref.read(notificationServiceProvider).requestPermission();
    } catch (_) {
      granted = false;
    }
    final ctrl = ref.read(onboardingControllerProvider.notifier);
    ctrl.setNotifications(granted);
    ctrl.setStreakGoal(7);
    final startLessonId = ref.read(onboardingControllerProvider).startingPoint;
    try {
      await ctrl.initLessons(startLessonId);
      await ctrl.complete(startLessonId);
    } catch (e) {
      debugPrint('[OnboardingNotificationsScreen] onboarding completion error: $e');
    }
    if (mounted) {
      setState(() => _loading = false);
      context.go(kRouteHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 24, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () => context.go(kRouteOnboardingGoal),
                  ),
                  const Expanded(
                    child: ProgressStepIndicator(currentStep: 4, totalSteps: 4),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: SpeechBubble(
                      text: "I'll remind you to practice so it becomes a habit!",
                      showTail: true,
                    ),
                  ),
                  SizedBox(height: 24),
                  MascotImage(assetName: 'owl_reading', size: 220),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : AppButton(
                      label: 'REMIND ME TO PRACTICE',
                      onPressed: _onRemind,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
