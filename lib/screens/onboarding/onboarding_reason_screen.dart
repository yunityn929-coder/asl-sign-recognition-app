import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/onboarding_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../widgets/app_button.dart';
import '../../widgets/mascot_image.dart';
import '../../widgets/progress_step_indicator.dart';
import '../../widgets/speech_bubble.dart';

const _kReasons = [
  ('family', 'Signing with family', Icons.favorite_rounded, Color(0xFFEF5DA8)),
  ('work', 'Signing at work', Icons.work_rounded, Color(0xFFFF9F45)),
  ('education', 'Supporting my education', Icons.school_rounded, Color(0xFF2EC4B6)),
  ('deaf', "I'm Deaf myself", Icons.front_hand_rounded, Color(0xFF4CC9F0)),
  ('people', 'Connecting with people', Icons.people_alt_rounded, Color(0xFF4361EE)),
  ('fun', 'For fun!', Icons.auto_awesome_rounded, Color(0xFFFF6B6B)),
];

// Onboarding: Reason for learning ASL
class OnboardingReasonScreen extends ConsumerStatefulWidget {
  const OnboardingReasonScreen({super.key});

  @override
  ConsumerState<OnboardingReasonScreen> createState() => _OnboardingReasonScreenState();
}

class _OnboardingReasonScreenState extends ConsumerState<OnboardingReasonScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final ctrl = ref.read(onboardingControllerProvider.notifier);

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
                    onPressed: () => context.go(kRouteWelcomePreview),
                  ),
                  const Expanded(
                    child: ProgressStepIndicator(currentStep: 1, totalSteps: 4),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MascotImage(assetName: 'owl_reading', size: 60),
                  SizedBox(width: 12),
                  Flexible(child: SpeechBubble(text: 'Why are you learning ASL?')),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: _kReasons
                    .map((r) => _ReasonCard(
                          label: r.$2,
                          icon: r.$3,
                          color: r.$4,
                          selected: state.reasons.contains(r.$1),
                          onTap: () => ctrl.toggleReason(r.$1),
                        ))
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: AppButton(
                label: 'CONTINUE',
                onPressed: state.reasons.isEmpty
                    ? null
                    : () => context.go(kRouteOnboardingLevel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ReasonCard({
    required this.label,
    required this.icon,
    required this.color,
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
          color: AppColors.backgroundCard,
          border: selected ? Border.all(color: color, width: 2) : null,
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
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            ),
            _ToggleIndicator(selected: selected, color: color),
          ],
        ),
      ),
    );
  }
}

class _ToggleIndicator extends StatelessWidget {
  final bool selected;
  final Color color;

  const _ToggleIndicator({required this.selected, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? color : Colors.transparent,
        border: selected ? null : Border.all(color: AppColors.textSecondary, width: 1.5),
      ),
      child: selected ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
    );
  }
}
