import 'package:flutter/material.dart';

class ResultHeader extends StatelessWidget {
  final int correctCount;
  final int totalCount;
  const ResultHeader(
      {super.key, required this.correctCount, required this.totalCount});

  @override
  Widget build(BuildContext context) {
    final String emoji;
    final String title;
    final String subtitle;
    if (correctCount == totalCount) {
      emoji = '🎉';
      title = 'Perfect!';
      subtitle = 'You got every sign right!';
    } else if (correctCount >= (totalCount * 0.7).ceil()) {
      emoji = '⭐';
      title = 'Great job!';
      subtitle = "You're getting there!";
    } else {
      emoji = '💪';
      title = 'Keep practising!';
      subtitle = 'Every attempt makes you better.';
    }
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 64)),
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111))),
        const SizedBox(height: 8),
        Text(subtitle,
            style: const TextStyle(fontSize: 16, color: Color(0xFF666666))),
      ],
    );
  }
}

