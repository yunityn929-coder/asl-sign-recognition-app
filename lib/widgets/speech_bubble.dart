import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

class SpeechBubble extends StatelessWidget {
  final String text;
  final bool showTail;

  const SpeechBubble({super.key, required this.text, this.showTail = false});

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          height: 1.4,
        ),
      ),
    );

    if (!showTail) return bubble;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        bubble,
        SizedBox(
          width: 16,
          height: 8,
          child: CustomPaint(painter: _SpeechBubbleTrianglePainter()),
        ),
      ],
    );
  }
}

class _SpeechBubbleTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fillPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = AppColors.backgroundCard);
  }

  @override
  bool shouldRepaint(_SpeechBubbleTrianglePainter old) => false;
}
