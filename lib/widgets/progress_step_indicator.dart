import 'package:flutter/material.dart';

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: LinearProgressIndicator(
        value: currentStep / totalSteps,
        backgroundColor: Colors.white24,
        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
        minHeight: 6,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
