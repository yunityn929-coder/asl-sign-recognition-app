import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

// Medal counts required per badge tier. Shared by the badge display and the
// tier-crossing detection so the two can't drift out of sync.
const List<int> kBadgeTiers = [5, 10, 20];

int medalCountForDifficulty(Map<String, bool> medalsEarned, String difficulty) =>
    medalsEarned.entries.where((e) => e.value && e.key.endsWith('_$difficulty')).length;

int badgeTierForCount(int count) => kBadgeTiers.where((t) => count >= t).length;

class BadgeKind {
  final String difficulty;
  final Color color;
  final String title;
  final String owlAsset;
  final String medalName;
  const BadgeKind(this.difficulty, this.color, this.title, this.owlAsset, this.medalName);
}

const List<BadgeKind> kBadgeKinds = [
  BadgeKind('easy', AppColors.medalBronze, 'Skilled Signer', 'owl_student', 'Bronze'),
  BadgeKind('medium', AppColors.medalSilver, 'Expert Signer', 'owl_expert', 'Silver'),
  BadgeKind('hard', AppColors.medalGold, 'Master Signer', 'owl_master', 'Gold'),
];

BadgeKind? badgeKindForDifficulty(String difficulty) {
  for (final kind in kBadgeKinds) {
    if (kind.difficulty == difficulty) return kind;
  }
  return null;
}
