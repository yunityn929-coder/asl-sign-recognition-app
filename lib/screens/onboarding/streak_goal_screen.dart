import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/onboarding_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../core/constants/xp_constants.dart';
import '../../services/tts_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/mascot_image.dart';
import '../../widgets/speech_bubble.dart';

const _kGoalOptions = [7, 14, 30, 50];

// S-12 — Streak Goal Selection
// Receives startLessonId via route extra (String).
class StreakGoalScreen extends ConsumerStatefulWidget {
  final String startLessonId;

  const StreakGoalScreen({super.key, required this.startLessonId});

  @override
  ConsumerState<StreakGoalScreen> createState() => _StreakGoalScreenState();
}

class _StreakGoalScreenState extends ConsumerState<StreakGoalScreen> {
  int _selectedDays = 7;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ttsServiceProvider).speak("Let's commit to learning with a Streak Goal!");
    });
  }

  Future<void> _onCommit() async {
    setState(() => _loading = true);
    final ctrl = ref.read(onboardingControllerProvider.notifier);
    ctrl.setStreakGoal(_selectedDays);
    try {
      await ctrl.complete(widget.startLessonId);
    } catch (_) {}
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
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MascotImage(assetName: 'mascot_commit', size: 56),
                  SizedBox(width: 8),
                  Icon(Icons.local_fire_department, color: Colors.orange, size: 32),
                  SizedBox(width: 8),
                  Flexible(
                    child: SpeechBubble(
                        text: "Let's commit to learning with a Streak Goal!"),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: _kGoalOptions
                    .map((days) => _GoalCard(
                          days: days,
                          xpBonus: kStreakGoalXp[days] ?? 0,
                          selected: _selectedDays == days,
                          onTap: () => setState(() => _selectedDays = days),
                        ))
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : AppButton(
                      label: 'COMMIT TO MY GOAL',
                      onPressed: _onCommit,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final int days;
  final int xpBonus;
  final bool selected;
  final VoidCallback onTap;

  const _GoalCard({
    required this.days,
    required this.xpBonus,
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
            const Icon(Icons.local_fire_department, color: Colors.orange, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$days days',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
            ),
            Text('+$xpBonus XP',
                style: TextStyle(
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
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
