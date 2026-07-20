import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/onboarding_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../widgets/app_button.dart';
import '../../widgets/mascot_image.dart';
import '../../widgets/speech_bubble.dart';

// S-09 — Onboarding Q4: Starting Point
class OnboardingStartScreen extends ConsumerStatefulWidget {
  const OnboardingStartScreen({super.key});

  @override
  ConsumerState<OnboardingStartScreen> createState() => _OnboardingStartScreenState();
}

class _OnboardingStartScreenState extends ConsumerState<OnboardingStartScreen> {
  String? _selected; // 'scratch' | 'find_level'
  bool _loading = false;

  Future<void> _onContinue() async {
    if (_selected == null) return;
    setState(() => _loading = true);
    final ctrl = ref.read(onboardingControllerProvider.notifier);
    ctrl.setStartingPoint(_selected!);

    if (_selected == 'find_level') {
      if (mounted) {
        setState(() => _loading = false);
        context.go(kRouteOnboardingPlacement);
      }
      return;
    }

    // 'scratch' — init lessons from s1l1 then go to streak goal
    try {
      await ctrl.initLessons('s1l1');
    } catch (_) {}
    if (mounted) {
      setState(() => _loading = false);
      context.go(kRouteOnboardingStreakGoal, extra: 's1l1');
    }
  }

  @override
  Widget build(BuildContext context) {
    final aslLevel = ref.watch(onboardingControllerProvider).aslLevel;
    final showFindLevel = aslLevel != 'none' && aslLevel.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.go(kRouteOnboardingAchievement),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MascotImage(assetName: 'mascot_speech', size: 56),
                  SizedBox(width: 12),
                  Flexible(child: SpeechBubble(text: 'Where would you like to start?')),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _StartCard(
                      icon: Icons.menu_book_rounded,
                      title: 'Start from scratch',
                      subtitle: 'Take the easiest lesson of the ASL course',
                      selected: _selected == 'scratch',
                      onTap: () => setState(() => _selected = 'scratch'),
                    ),
                    const SizedBox(height: 12),
                    if (showFindLevel)
                      _StartCard(
                        icon: Icons.explore_rounded,
                        title: 'Find my level',
                        subtitle: 'Let me recommend where you should start',
                        recommended: true,
                        selected: _selected == 'find_level',
                        onTap: () => setState(() => _selected = 'find_level'),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : AppButton(
                      label: 'CONTINUE',
                      onPressed: _selected == null ? null : _onContinue,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool recommended;
  final bool selected;
  final VoidCallback onTap;

  const _StartCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.recommended = false,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(18),
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
            Icon(icon,
                color: selected ? AppColors.primary : AppColors.textSecondary, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      if (recommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(4)),
                          child: const Text('RECOMMENDED',
                              style: TextStyle(
                                  color: AppColors.textOnDark,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
