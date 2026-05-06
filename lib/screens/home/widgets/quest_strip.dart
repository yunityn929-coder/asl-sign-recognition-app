import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

// Horizontal quest strip — shows 3 quest placeholder cards.
// Replace placeholder with real QuestProvider data once QuestProvider is built.
class QuestStrip extends StatelessWidget {
  const QuestStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemCount: 3,
        itemBuilder: (context, i) => const _QuestPlaceholder(),
      ),
    );
  }
}

class _QuestPlaceholder extends StatelessWidget {
  const _QuestPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 176,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events_outlined, size: 14, color: AppColors.xpGold),
              SizedBox(width: 4),
              Text(
                'Daily Quest',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          const Text(
            'Loading quests...',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              value: 0,
              minHeight: 4,
              backgroundColor: AppColors.primarySoft,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
