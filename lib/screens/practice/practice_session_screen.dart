import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// S-14 — Practice Session
class PracticeSessionScreen extends ConsumerWidget {
  final String lessonId;
  final String difficulty;
  const PracticeSessionScreen({
    required this.lessonId,
    required this.difficulty,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(child: Text('Practice Session — TODO')),
    );
  }
}
