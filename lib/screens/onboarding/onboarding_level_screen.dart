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

const _kLevels = [
  ('none', "I'm new to ASL", 1),
  ('alphabet', 'I know the alphabet', 2),
  ('common_words', 'I know some common words', 3),
  ('conversational', 'I can have a basic ASL conversation', 4),
];

String _startLessonIdForLevel(String level) {
  switch (level) {
    case 'alphabet':
      return 's2l1';
    case 'common_words':
      return 's2l4';
    case 'conversational':
      return 's1l6';
    case 'none':
    default:
      return 's1l1';
  }
}

// S-05 — Onboarding Q1: ASL Level
class OnboardingLevelScreen extends ConsumerStatefulWidget {
  const OnboardingLevelScreen({super.key});

  @override
  ConsumerState<OnboardingLevelScreen> createState() => _OnboardingLevelScreenState();
}

class _OnboardingLevelScreenState extends ConsumerState<OnboardingLevelScreen> {
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
                    onPressed: () => context.go(kRouteOnboardingReason),
                  ),
                  const Expanded(
                    child: ProgressStepIndicator(currentStep: 2, totalSteps: 4),
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
                          level: l.$3,
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
                onPressed: state.aslLevel.isEmpty
                    ? null
                    : () {
                        ctrl.setStartingPoint(_startLessonIdForLevel(state.aslLevel));
                        context.go(kRouteOnboardingGoal);
                      },
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
  final int level;
  final bool selected;
  final VoidCallback onTap;

  const _LevelCard({
    required this.label,
    required this.level,
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
            _LevelBarsIcon(
              level: level,
              activeColor: selected ? AppColors.primary : AppColors.textSecondary,
            ),
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

class _LevelBarsIcon extends StatelessWidget {
  final int level; // 1-based; how many of the 4 bars are filled
  final Color activeColor;
  static const int _totalBars = 4;
  static const Color _inactiveColor = Color(0xFFD9D9D9);

  const _LevelBarsIcon({required this.level, required this.activeColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 18,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(_totalBars, (i) {
          final barHeight = 5.0 + i * 4.0;
          final filled = i < level;
          return Container(
            width: 3.5,
            height: barHeight,
            margin: EdgeInsets.only(right: i == _totalBars - 1 ? 0 : 2),
            decoration: BoxDecoration(
              color: filled ? activeColor : _inactiveColor,
              borderRadius: BorderRadius.circular(1),
            ),
          );
        }),
      ),
    );
  }
}
