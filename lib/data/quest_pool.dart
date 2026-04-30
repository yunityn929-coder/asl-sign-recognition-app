class QuestDefinition {
  final String type;
  final int target;
  final String description;

  const QuestDefinition({
    required this.type,
    required this.target,
    required this.description,
  });
}

const List<QuestDefinition> kQuestPool = [
  QuestDefinition(type: 'complete_lessons',   target: 1,  description: 'Complete 1 lesson today'),
  QuestDefinition(type: 'complete_lessons',   target: 2,  description: 'Complete 2 lessons today'),
  QuestDefinition(type: 'earn_xp',            target: 50, description: 'Earn 50 XP today'),
  QuestDefinition(type: 'earn_xp',            target: 100,description: 'Earn 100 XP today'),
  QuestDefinition(type: 'practice_sessions',  target: 1,  description: 'Complete 1 practice session'),
  QuestDefinition(type: 'practice_sessions',  target: 3,  description: 'Complete 3 practice sessions'),
  QuestDefinition(type: 'correct_streak',     target: 5,  description: 'Get 5 signs correct in a row'),
  QuestDefinition(type: 'correct_streak',     target: 10, description: 'Get 10 signs correct in a row'),
];
