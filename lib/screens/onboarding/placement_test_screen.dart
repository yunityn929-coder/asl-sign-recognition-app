import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/onboarding_controller.dart';
import '../../controllers/placement_test_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';

// S-10 — Placement Test
// 10 random signs, 5s timer per sign, no skip, no TTS, no XP.
// Signs auto-advance on timeout (camera recognition not wired yet).
class PlacementTestScreen extends ConsumerStatefulWidget {
  const PlacementTestScreen({super.key});

  @override
  ConsumerState<PlacementTestScreen> createState() => _PlacementTestScreenState();
}

class _PlacementTestScreenState extends ConsumerState<PlacementTestScreen> {
  late final String _aslLevel;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _aslLevel = ref.read(onboardingControllerProvider).aslLevel;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(placementTestControllerProvider(_aslLevel).notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(placementTestControllerProvider(_aslLevel), (prev, next) {
      if (next.isComplete && !(prev?.isComplete ?? false) && !_navigating && mounted) {
        _navigating = true;
        final notifier = ref.read(placementTestControllerProvider(_aslLevel).notifier);
        context.go(
          kRouteOnboardingPlacementResult,
          extra: {
            'startLessonId': notifier.startLessonId(),
            'correctCount': next.correctCount,
          },
        );
      }
    });

    final state = ref.watch(placementTestControllerProvider(_aslLevel));

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Let's find your level",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: state.itemProgress,
                    backgroundColor: AppColors.primarySoft,
                    color: AppColors.primary,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${state.currentIndex + 1} / ${state.totalSigns}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Sign:',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.currentSign,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 96,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Hold your hand up to the camera\nand show the sign',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                children: [
                  Text(
                    '${state.timeLeftSeconds}s',
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: state.timeProgress,
                    backgroundColor: AppColors.primarySoft,
                    color: state.timeLeftSeconds <= 2 ? AppColors.error : AppColors.primary,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
