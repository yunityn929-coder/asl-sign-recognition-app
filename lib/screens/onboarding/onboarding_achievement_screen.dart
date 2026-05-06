import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../services/tts_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/mascot_image.dart';
import '../../widgets/progress_step_indicator.dart';
import '../../widgets/speech_bubble.dart';

const _kFeatures = [
  (Icons.sign_language_rounded, '🤟 Sign with confidence', 'Learn every letter and number'),
  (Icons.bolt, '⚡ Build your vocabulary', 'Fingerspell real words'),
  (Icons.local_fire_department, '🔥 Develop a habit', 'Streaks, quests, and daily goals'),
];

// S-08 — Onboarding: Achievement Preview
class OnboardingAchievementScreen extends ConsumerStatefulWidget {
  const OnboardingAchievementScreen({super.key});

  @override
  ConsumerState<OnboardingAchievementScreen> createState() =>
      _OnboardingAchievementScreenState();
}

class _OnboardingAchievementScreenState extends ConsumerState<OnboardingAchievementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ttsServiceProvider).speak("Here's what you can achieve!");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.go(kRouteOnboardingNotifications),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ProgressStepIndicator(currentStep: 4, totalSteps: 4),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MascotImage(assetName: 'mascot_speech', size: 56),
                  SizedBox(width: 12),
                  Flexible(child: SpeechBubble(text: "Here's what you can achieve!")),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _kFeatures
                      .map((f) => _FeatureRow(icon: f.$1, title: f.$2, subtitle: f.$3))
                      .toList(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: AppButton(
                label: 'CONTINUE',
                onPressed: () => context.go(kRouteOnboardingStart),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.backgroundAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}
