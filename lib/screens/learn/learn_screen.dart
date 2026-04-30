import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// S-12 — Learn Session
class LearnScreen extends ConsumerWidget {
  final String lessonId;
  const LearnScreen({required this.lessonId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(child: Text('Learn Session — TODO')),
    );
  }
}
