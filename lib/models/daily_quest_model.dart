class DailyQuestModel {
  final String date;
  final String generatedAt;
  final List<QuestModel> quests;
  final int totalQuestsCompleted;

  const DailyQuestModel({
    required this.date,
    required this.generatedAt,
    required this.quests,
    required this.totalQuestsCompleted,
  });

  DailyQuestModel copyWith({
    List<QuestModel>? quests,
    int? totalQuestsCompleted,
  }) =>
      DailyQuestModel(
        date: date,
        generatedAt: generatedAt,
        quests: quests ?? this.quests,
        totalQuestsCompleted: totalQuestsCompleted ?? this.totalQuestsCompleted,
      );

  factory DailyQuestModel.fromMap(Map<String, dynamic> map) => DailyQuestModel(
        date: map['date'] as String,
        generatedAt: map['generatedAt'] as String,
        quests: (map['quests'] as List<dynamic>)
            .map((e) => QuestModel.fromMap(e as Map<String, dynamic>))
            .toList(),
        totalQuestsCompleted: (map['totalQuestsCompleted'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'date': date,
        'generatedAt': generatedAt,
        'quests': quests.map((e) => e.toMap()).toList(),
        'totalQuestsCompleted': totalQuestsCompleted,
      };
}

// Inline here to keep daily_quest_model.dart self-contained; QuestModel has its own file too.
class QuestModel {
  final String id;
  final String type;
  final String description;
  final int target;
  final int progress;
  final bool completed;
  final int xpReward;
  // True once the user has tapped the treasure chest to claim xpReward for
  // this quest. Distinct from `completed` (target reached) — a quest can be
  // completed and awaiting collection, or completed and collected.
  final bool collected;

  const QuestModel({
    required this.id,
    required this.type,
    required this.description,
    required this.target,
    required this.progress,
    required this.completed,
    required this.xpReward,
    this.collected = false,
  });

  QuestModel copyWith({int? progress, bool? completed, bool? collected}) =>
      QuestModel(
        id: id,
        type: type,
        description: description,
        target: target,
        progress: progress ?? this.progress,
        completed: completed ?? this.completed,
        xpReward: xpReward,
        collected: collected ?? this.collected,
      );

  factory QuestModel.fromMap(Map<String, dynamic> map) => QuestModel(
        id: map['id'] as String,
        type: map['type'] as String,
        description: map['description'] as String,
        target: (map['target'] as num).toInt(),
        progress: (map['progress'] as num?)?.toInt() ?? 0,
        completed: map['completed'] as bool? ?? false,
        xpReward: (map['xpReward'] as num?)?.toInt() ?? 30,
        collected: map['collected'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'description': description,
        'target': target,
        'progress': progress,
        'completed': completed,
        'xpReward': xpReward,
        'collected': collected,
      };
}
