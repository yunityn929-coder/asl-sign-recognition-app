import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/onboarding_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../services/tts_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/mascot_image.dart';
import '../../widgets/progress_step_indicator.dart';
import '../../widgets/speech_bubble.dart';

const _kGoals = [
  (5,  'Casual'),
  (10, 'Regular'),
  (15, 'Serious'),
  (20, 'Intense'),
];

// S-06 — Onboarding Q2: Daily Goal
class OnboardingGoalScreen extends ConsumerStatefulWidget {
  const OnboardingGoalScreen({super.key});

  @override
  ConsumerState<OnboardingGoalScreen> createState() => _OnboardingGoalScreenState();
}

class _OnboardingGoalScreenState extends ConsumerState<OnboardingGoalScreen> {
  // dailyGoalMinutes defaults to 5 in OnboardingState so treat 0 as unselected.
  int? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ttsServiceProvider).speak("What's your daily learning goal?");
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = ref.read(onboardingControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.go(kRouteOnboardingLevel),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ProgressStepIndicator(currentStep: 2, totalSteps: 4),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MascotImage(assetName: 'mascot_speech', size: 56),
                  SizedBox(width: 12),
                  Flexible(
                    child: SpeechBubble(text: "What's your daily learning goal?"),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: _kGoals
                    .map((g) => _GoalCard(
                          minutes: g.$1,
                          label: g.$2,
                          selected: _selected == g.$1,
                          onTap: () => setState(() => _selected = g.$1),
                        ))
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: AppButton(
                label: "I'M COMMITTED",
                onPressed: _selected == null
                    ? null
                    : () {
                        ctrl.setDailyGoal(_selected!);
                        context.go(kRouteOnboardingNotifications);
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final int minutes;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GoalCard({
    required this.minutes,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.backgroundCard,
          border: selected ? Border.all(color: AppColors.primary, width: 2) : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(Icons.timer_outlined,
                color: selected ? AppColors.primary : AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text('$minutes min / day',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
            ),
            Text(label,
                style: TextStyle(
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                    fontSize: 13)),
            if (selected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
