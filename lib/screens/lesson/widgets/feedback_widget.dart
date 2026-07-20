import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/feedback_service.dart';

/// Bottom-of-camera pill/banner showing the current [FeedbackState] from
/// FeedbackService. Purely presentational — fades between states only.
class FeedbackWidget extends StatelessWidget {
  final FeedbackState state;
  final String message;

  const FeedbackWidget({
    required this.state,
    required this.message,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(state);
    final isCorrect = state == FeedbackState.correct;

    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: Container(
            key: ValueKey(state),
            padding: EdgeInsets.symmetric(
              horizontal: isCorrect ? 22 : 18,
              vertical: isCorrect ? 13 : 10,
            ),
            decoration: BoxDecoration(
              color: style.background,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(style.icon,
                    size: isCorrect ? 22 : 18, color: style.foreground),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isCorrect ? 16 : 14,
                      fontWeight: FontWeight.w700,
                      color: style.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _FeedbackStyle _styleFor(FeedbackState state) {
    switch (state) {
      case FeedbackState.noHand:
        return const _FeedbackStyle(
          background: Color(0xCC4A4A4A),
          foreground: Colors.white,
          icon: Icons.pan_tool_outlined,
        );
      case FeedbackState.correctHeld:
        return const _FeedbackStyle(
          background: Color(0xFFFFD166),
          foreground: Color(0xFF6B4E00),
          icon: Icons.hourglass_top_rounded,
        );
      case FeedbackState.correct:
        return const _FeedbackStyle(
          background: AppColors.success,
          foreground: Colors.white,
          icon: Icons.check_circle_rounded,
        );
      case FeedbackState.wrongClear:
        return const _FeedbackStyle(
          background: AppColors.warning,
          foreground: Color(0xFF5A3A00),
          icon: Icons.info_rounded,
        );
      case FeedbackState.wrongUnclear:
        return const _FeedbackStyle(
          background: Color(0xCC4A4A4A),
          foreground: Colors.white,
          icon: Icons.back_hand_outlined,
        );
      case FeedbackState.noHandTimeout:
        return const _FeedbackStyle(
          background: Color(0xCC4A4A4A),
          foreground: Colors.white,
          icon: Icons.pan_tool_outlined,
        );
      case FeedbackState.tooDark:
        return const _FeedbackStyle(
          background: AppColors.warning,
          foreground: Color(0xFF5A3A00),
          icon: Icons.brightness_low_rounded,
        );
      case FeedbackState.tooBright:
        return const _FeedbackStyle(
          background: AppColors.warning,
          foreground: Color(0xFF5A3A00),
          icon: Icons.brightness_high_rounded,
        );
      case FeedbackState.tooFar:
        return const _FeedbackStyle(
          background: AppColors.warning,
          foreground: Color(0xFF5A3A00),
          icon: Icons.zoom_in_rounded,
        );
      case FeedbackState.tooClose:
        return const _FeedbackStyle(
          background: AppColors.warning,
          foreground: Color(0xFF5A3A00),
          icon: Icons.zoom_out_rounded,
        );
    }
  }
}

class _FeedbackStyle {
  final Color background;
  final Color foreground;
  final IconData icon;

  const _FeedbackStyle({
    required this.background,
    required this.foreground,
    required this.icon,
  });
}
