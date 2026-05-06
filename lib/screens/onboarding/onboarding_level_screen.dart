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

const _kLevels = [
  ('none', "I'm new to ASL"),
  ('some', 'I know some signs'),
  ('alphabet', 'I know the alphabet'),
  ('conversational', 'I can have a basic ASL conversation'),
];

// S-05 — Onboarding Q1: ASL Level
class OnboardingLevelScreen extends ConsumerStatefulWidget {
  const OnboardingLevelScreen({super.key});

  @override
  ConsumerState<OnboardingLevelScreen> createState() => _OnboardingLevelScreenState();
}

class _OnboardingLevelScreenState extends ConsumerState<OnboardingLevelScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ttsServiceProvider).speak('How much ASL do you know?');
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final ctrl = ref.read(onboardingControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.go(kRouteWelcomePreview),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ProgressStepIndicator(currentStep: 1, totalSteps: 4),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MascotImage(assetName: 'mascot_speech', size: 56),
                  SizedBox(width: 12),
                  Flexible(child: SpeechBubble(text: 'How much ASL do you know?')),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: _kLevels
                    .map((l) => _LevelCard(
                          label: l.$2,
                          selected: state.aslLevel == l.$1,
                          onTap: () => ctrl.setAslLevel(l.$1),
                        ))
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: AppButton(
                label: 'CONTINUE',
                onPressed:
                    state.aslLevel.isEmpty ? null : () => context.go(kRouteOnboardingGoal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LevelCard({required this.label, required this.selected, required this.onTap});

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
            Icon(Icons.signal_cellular_alt,
                color: selected ? AppColors.primary : AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
            ),
            if (selected) const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
