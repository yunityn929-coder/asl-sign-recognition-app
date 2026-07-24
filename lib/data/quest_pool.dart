class QuestDefinition {
  final String type;
  // For 'spend_minutes' this is a sentinel (0) — its real target is resolved
  // per-user at generation/reconcile time from user.dailyGoalMinutes (see
  // FirestoreService._resolveTarget). All other quest types use this value
  // directly.
  final int target;
  final String description;
  final int xpReward;

  const QuestDefinition({
    required this.type,
    required this.target,
    required this.description,
    required this.xpReward,
  });
}

// Fixed daily quest set — same quests every day, no randomization.
const List<QuestDefinition> kQuestPool = [
  QuestDefinition(type: 'high_score_lessons', target: 3, description: 'Score 90% or above in 3 lessons', xpReward: 10),
  QuestDefinition(type: 'spend_minutes',      target: 0, description: 'Spend time learning', xpReward: 10),
  QuestDefinition(type: 'earn_xp',            target: 100, description: 'Earn 100 XP', xpReward: 20),
];
