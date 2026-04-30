import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/onboarding_controller.dart';
import '../../core/constants/route_constants.dart';
import '../../services/notification_service.dart';
import '../../services/tts_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/mascot_image.dart';
import '../../widgets/progress_step_indicator.dart';
import '../../widgets/speech_bubble.dart';

const _kDarkBg = Color(0xFF1A1A2E);

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ttsServiceProvider).speak("I'll remind you to practice so it becomes a habit!");
    });
  }

  Future<void> _onRemind() async {
    setState(() => _loading = true);
    final granted = await ref.read(notificationServiceProvider).requestPermission();
    ref.read(onboardingControllerProvider.notifier).setNotifications(granted);
    if (mounted) {
      setState(() => _loading = false);
      context.go(kRouteOnboardingAchievement);
    }
  }

  void _onMaybeLater() {
    ref.read(onboardingControllerProvider.notifier).setNotifications(false);
    context.go(kRouteOnboardingAchievement);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDarkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go(kRouteOnboardingGoal),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ProgressStepIndicator(currentStep: 3, totalSteps: 4),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MascotImage(assetName: 'mascot_speech', size: 56),
                  SizedBox(width: 12),
                  Flexible(
                    child: SpeechBubble(
                      text: "I'll remind you to practice so it becomes a habit!",
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(child: SizedBox()),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : AppButton(
                      label: 'REMIND ME TO PRACTICE',
                      onPressed: _onRemind,
                    ),
            ),
            Center(
              child: AppButton(
                label: 'Maybe later',
                onPressed: _onMaybeLater,
                isSecondary: true,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
