import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// S-16 — Learn Completion
class LearnCompletionScreen extends ConsumerWidget {
  final String lessonId;
  const LearnCompletionScreen({required this.lessonId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(child: Text('Learn Complete — TODO')),
    );
  }
}
