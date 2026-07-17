import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: const Center(
        child: Text(
          'Coming soon',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
        ),
      ),
    );
  }
}
