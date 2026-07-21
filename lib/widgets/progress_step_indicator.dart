import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class ProgressStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const ProgressStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: currentStep / totalSteps,
      backgroundColor: AppColors.backgroundCard,
      color: AppColors.primary,
      minHeight: 6,
      borderRadius: BorderRadius.circular(3),
    );
  }
}
