import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../widgets/app_button.dart';

// S-02 — Welcome: Brand Screen
class WelcomeBrandScreen extends ConsumerWidget {
  const WelcomeBrandScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: ColoredBox(
        color: AppColors.backgroundPrimary,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/owl.png', width: 200, height: 200),
                    const SizedBox(height: 32),
                    const Text(
                      'HiASL',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Learn the language of silenece',
                      style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  children: [
                    AppButton(
                      label: 'GET STARTED',
                      onPressed: () => context.go(kRouteWelcomePreview),
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'I already have an account',
                      onPressed: () => context.push(kRouteSignIn),
                      isSecondary: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
