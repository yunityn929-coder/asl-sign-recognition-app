import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// S-11 — Mode Select
class ModeSelectScreen extends ConsumerWidget {
  final String lessonId;
  const ModeSelectScreen({required this.lessonId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(child: Text('Mode Select — TODO')),
    );
  }
}
