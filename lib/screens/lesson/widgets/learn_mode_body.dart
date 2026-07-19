import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/quiz_service.dart';

class LearnModeBody extends StatelessWidget {
  final String sign;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onHint;

  const LearnModeBody({
    super.key,
    required this.sign,
    required this.onPrevious,
    required this.onNext,
    required this.onHint,
  });

  String get _signName {
    const digits = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9'};
    return digits.contains(sign) ? 'Number $sign' : 'Sign $sign';
  }

  bool get _hasImage => kAvailableSigns.contains(sign);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 260,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x15000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              if (_hasImage) ...[
                Image.asset(
                  '$kSignImagePath$sign.png',
                  height: 160,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded),
                      color: onPrevious != null
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      iconSize: 24,
                      onPressed: onPrevious,
                    ),
                    Text(
                      _signName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded),
                      color: onNext != null
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      iconSize: 24,
                      onPressed: onNext,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: onHint,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(blurRadius: 4, color: Colors.black12),
                ],
              ),
              child: const Icon(
                Icons.lightbulb_outline_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
