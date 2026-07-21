import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../widgets/app_button.dart';
import '../../widgets/mascot_image.dart';
import '../../widgets/speech_bubble.dart';

// S-04 — Welcome: Questions Preview
class WelcomePreviewScreen extends ConsumerStatefulWidget {
  const WelcomePreviewScreen({super.key});

  @override
  ConsumerState<WelcomePreviewScreen> createState() => _WelcomePreviewScreenState();
}

class _WelcomePreviewScreenState extends ConsumerState<WelcomePreviewScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(kRouteWelcomeBrand),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: SpeechBubble(
                      text: 'Just 4 quick questions before we start!',
                      showTail: true,
                    ),
                  ),
                  SizedBox(height: 24),
                  MascotImage(assetName: 'owl_reading', size: 220),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: AppButton(
                label: 'CONTINUE',
                onPressed: () => context.go(kRouteOnboardingReason),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
