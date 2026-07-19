class LessonModel {
  final String lessonId;
  final int sectionNumber;
  final String status; // "locked" | "available" | "completed"
  final String? completedAt;
  final int practiceCount;
  final double bestAccuracy;
  final int totalXpEarned;
  final bool practiceUnlocked;
  final int lastSignIndex;

  const LessonModel({
    required this.lessonId,
    required this.sectionNumber,
    required this.status,
    this.completedAt,
    required this.practiceCount,
    required this.bestAccuracy,
    required this.totalXpEarned,
    this.practiceUnlocked = false,
    this.lastSignIndex = 0,
  });

  LessonModel copyWith({
    String? status,
    String? completedAt,
    int? practiceCount,
    double? bestAccuracy,
    int? totalXpEarned,
    bool? practiceUnlocked,
    int? lastSignIndex,
  }) =>
      LessonModel(
        lessonId: lessonId,
        sectionNumber: sectionNumber,
        status: status ?? this.status,
        completedAt: completedAt ?? this.completedAt,
        practiceCount: practiceCount ?? this.practiceCount,
        bestAccuracy: bestAccuracy ?? this.bestAccuracy,
        totalXpEarned: totalXpEarned ?? this.totalXpEarned,
        practiceUnlocked: practiceUnlocked ?? this.practiceUnlocked,
        lastSignIndex: lastSignIndex ?? this.lastSignIndex,
      );

  factory LessonModel.fromMap(Map<String, dynamic> map) => LessonModel(
        lessonId: map['lessonId'] as String,
        sectionNumber: (map['sectionNumber'] as num).toInt(),
        status: map['status'] as String,
        completedAt: map['completedAt'] as String?,
        practiceCount: (map['practiceCount'] as num?)?.toInt() ?? 0,
        bestAccuracy: (map['bestAccuracy'] as num?)?.toDouble() ?? 0.0,
        totalXpEarned: (map['totalXpEarned'] as num?)?.toInt() ?? 0,
        practiceUnlocked: map['practiceUnlocked'] as bool? ?? false,
        lastSignIndex: (map['lastSignIndex'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'lessonId': lessonId,
        'sectionNumber': sectionNumber,
        'status': status,
        if (completedAt != null) 'completedAt': completedAt,
        'practiceCount': practiceCount,
        'bestAccuracy': bestAccuracy,
        'totalXpEarned': totalXpEarned,
        'practiceUnlocked': practiceUnlocked,
        'lastSignIndex': lastSignIndex,
      };

  factory LessonModel.empty() => const LessonModel(
        lessonId: '',
        sectionNumber: 0,
        status: 'locked',
        completedAt: null,
        practiceCount: 0,
        bestAccuracy: 0,
        totalXpEarned: 0,
        practiceUnlocked: false,
        lastSignIndex: 0,
      );
}
