import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/onboarding_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../data/lesson_definitions.dart';
import '../../widgets/app_button.dart';
import '../../widgets/mascot_image.dart';

const _kLevelLabels = {
  'none': "I'm new to ASL",
  'some': 'I know some signs',
  'alphabet': 'I know the alphabet',
  'conversational': 'I can have a basic ASL conversation',
};

// S-11 — Placement Result
// Receives startLessonId and correctCount via route extra Map.
class PlacementResultScreen extends ConsumerStatefulWidget {
  final String startLessonId;
  final int correctCount;

  const PlacementResultScreen({
    super.key,
    required this.startLessonId,
    required this.correctCount,
  });

  @override
  ConsumerState<PlacementResultScreen> createState() => _PlacementResultScreenState();
}

class _PlacementResultScreenState extends ConsumerState<PlacementResultScreen> {
  bool _loading = false;

  String get _sectionName {
    final sectionNum = int.tryParse(widget.startLessonId.substring(1, 2)) ?? 1;
    return kSections.firstWhere((s) => s.number == sectionNum).title;
  }

  Future<void> _onLetsGo() async {
    setState(() => _loading = true);
    try {
      await ref.read(onboardingControllerProvider.notifier).initLessons(widget.startLessonId);
    } catch (_) {}
    if (mounted) {
      setState(() => _loading = false);
      context.go(kRouteOnboardingStreakGoal, extra: widget.startLessonId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aslLevel = ref.read(onboardingControllerProvider).aslLevel;
    final levelLabel = _kLevelLabels[aslLevel] ?? aslLevel;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const MascotImage(assetName: 'mascot_celebrate', size: 180),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 20, height: 1.5),
                        children: [
                          const TextSpan(text: 'Since you said '),
                          TextSpan(
                            text: '"$levelLabel"',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: ', you should start with '),
                          TextSpan(
                            text: _sectionName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: '!'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Score: ${widget.correctCount} / 10',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : AppButton(
                      label: "LET'S GO",
                      onPressed: _onLetsGo,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
