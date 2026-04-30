import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_constants.dart';
import '../../services/tts_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/mascot_image.dart';
import '../../widgets/speech_bubble.dart';

const _kDarkBg = Color(0xFF1A1A2E);
const _kSpeech = 'Just 4 quick questions before we start your first lesson!';

// S-04 — Welcome: Questions Preview
class WelcomePreviewScreen extends ConsumerStatefulWidget {
  const WelcomePreviewScreen({super.key});

  @override
  ConsumerState<WelcomePreviewScreen> createState() => _WelcomePreviewScreenState();
}

class _WelcomePreviewScreenState extends ConsumerState<WelcomePreviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ttsServiceProvider).speak(_kSpeech);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDarkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go(kRouteWelcomeIntro),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MascotImage(assetName: 'mascot_excited', size: 180),
                  SizedBox(height: 24),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: SpeechBubble(text: 'Just 4 quick questions before we start!'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: AppButton(
                label: 'CONTINUE',
                onPressed: () => context.go(kRouteOnboardingLevel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
