import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// S-25 — Google Sign-In (social unlock)
class SocialSignInScreen extends ConsumerWidget {
  const SocialSignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(child: Text('Google Sign-In — TODO')),
    );
  }
}
