import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// S-13 — Practice Setup
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
