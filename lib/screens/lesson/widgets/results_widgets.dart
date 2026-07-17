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

class ResultScoreCard extends StatelessWidget {
  final int correctCount;
  final int totalCount;
  final int xpEarned;
  const ResultScoreCard(
      {super.key,
      required this.correctCount,
      required this.totalCount,
      required this.xpEarned});

  @override
  Widget build(BuildContext context) {
    final missed = totalCount - correctCount;
    final missedColor = correctCount == totalCount
        ? const Color(0xFF5BC8AC)
        : const Color(0xFFFF8A8A);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x15000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatBox(
              value: '$correctCount',
              label: 'Correct',
              color: const Color(0xFF5BC8AC)),
          _StatBox(
              value: '+$xpEarned',
              label: 'XP',
              color: const Color(0xFFFFD166)),
          _StatBox(value: '$missed', label: 'Missed', color: missedColor),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatBox(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA))),
      ],
    );
  }
}

class ResultMissedSignsRow extends StatelessWidget {
  final List<String> missedSigns;
  const ResultMissedSignsRow({super.key, required this.missedSigns});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review these signs:',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111111)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: missedSigns.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _MissedCard(sign: missedSigns[i]),
          ),
        ),
      ],
    );
  }
}

class _MissedCard extends StatelessWidget {
  final String sign;
  const _MissedCard({required this.sign});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x10000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(sign,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFCCCCCC))),
          const SizedBox(height: 6),
          Text(sign,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF444444))),
        ],
      ),
    );
  }
}
