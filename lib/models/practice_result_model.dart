class PracticeItemResult {
  final String sign;
  final String result; // "correct" | "missed" | "timeout"
  final int timeTakenMs;

  const PracticeItemResult({
    required this.sign,
    required this.result,
    required this.timeTakenMs,
  });

  factory PracticeItemResult.fromMap(Map<String, dynamic> map) =>
      PracticeItemResult(
        sign: map['sign'] as String,
        result: map['result'] as String,
        timeTakenMs: (map['timeTakenMs'] as num).toInt(),
      );

  Map<String, dynamic> toMap() => {
        'sign': sign,
        'result': result,
        'timeTakenMs': timeTakenMs,
      };
}

class PracticeResultModel {
  final String lessonId;
  final String sessionType; // "learn" | "practice" | "placement"
  final String difficulty;  // "easy" | "medium" | "hard" | "n/a"
  final String completedAt;
  final int durationSeconds;
  final int totalItems;
  final int correctCount;
  final double accuracyPercent;
  final int xpEarned;
  final List<PracticeItemResult> items;

  const PracticeResultModel({
    required this.lessonId,
    required this.sessionType,
    required this.difficulty,
    required this.completedAt,
    required this.durationSeconds,
    required this.totalItems,
    required this.correctCount,
    required this.accuracyPercent,
    required this.xpEarned,
    required this.items,
  });

  factory PracticeResultModel.fromMap(Map<String, dynamic> map) =>
      PracticeResultModel(
        lessonId: map['lessonId'] as String,
        sessionType: map['sessionType'] as String,
        difficulty: map['difficulty'] as String,
        completedAt: map['completedAt'] as String,
        durationSeconds: (map['durationSeconds'] as num).toInt(),
        totalItems: (map['totalItems'] as num).toInt(),
        correctCount: (map['correctCount'] as num).toInt(),
        accuracyPercent: (map['accuracyPercent'] as num).toDouble(),
        xpEarned: (map['xpEarned'] as num).toInt(),
        items: (map['items'] as List<dynamic>)
            .map((e) => PracticeItemResult.fromMap(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'lessonId': lessonId,
        'sessionType': sessionType,
        'difficulty': difficulty,
        'completedAt': completedAt,
        'durationSeconds': durationSeconds,
        'totalItems': totalItems,
        'correctCount': correctCount,
        'accuracyPercent': accuracyPercent,
        'xpEarned': xpEarned,
        'items': items.map((e) => e.toMap()).toList(),
      };
}
