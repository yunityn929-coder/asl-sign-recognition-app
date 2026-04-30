import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// S-08 — Placement Test
class PlacementTestScreen extends ConsumerWidget {
  const PlacementTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(child: Text('Placement Test — TODO')),
    );
  }
}
