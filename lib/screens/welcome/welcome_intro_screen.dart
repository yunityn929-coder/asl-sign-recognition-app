import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../services/tts_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/mascot_image.dart';
import '../../widgets/speech_bubble.dart';

// S-03 — Welcome: Mascot Intro
class WelcomeIntroScreen extends ConsumerStatefulWidget {
  const WelcomeIntroScreen({super.key});

  @override
  ConsumerState<WelcomeIntroScreen> createState() => _WelcomeIntroScreenState();
}

class _WelcomeIntroScreenState extends ConsumerState<WelcomeIntroScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ttsServiceProvider).speak("Hi there! I'm Hani!");
    });
  }

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
                  MascotImage(assetName: 'mascot_speech', size: 180),
                  SizedBox(height: 24),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: SpeechBubble(text: "Hi there! I'm Hani! 🤟"),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "I'll be your ASL learning buddy",
                    style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: AppButton(
                label: 'CONTINUE',
                onPressed: () => context.go(kRouteWelcomePreview),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
