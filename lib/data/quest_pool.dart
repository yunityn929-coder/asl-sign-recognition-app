class QuestDefinition {
  final String type;
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
  QuestDefinition(type: 'complete_lessons', target: 1,   description: 'Complete 1 lesson today', xpReward: 5),
  QuestDefinition(type: 'play_quiz',        target: 1,   description: 'Play 1 quiz today', xpReward: 20),
  QuestDefinition(type: 'earn_xp',          target: 300, description: 'Earn 300 XP today', xpReward: 30),
];
