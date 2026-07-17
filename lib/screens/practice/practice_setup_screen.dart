import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// S-17 — Practice Setup
//
// TODO(integration): No camera/recognition wiring needed here — this screen
// only picks difficulty (Easy/Medium/Hard cards, default Easy) and passes it
// as `extra` to PracticeSessionScreen (see router.dart kRoutePracticeSession),
// which owns all camera + RecognitionController setup.
class PracticeSetupScreen extends ConsumerWidget {
  final String lessonId;
  const PracticeSetupScreen({required this.lessonId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(child: Text('Practice Setup — TODO')),
    );
  }
}
