class LessonModel {
  final String lessonId;
  final int sectionNumber;
  final String status; // "locked" | "available" | "completed"
  final String? completedAt;
  final int practiceCount;
  final double bestAccuracy;
  final int totalXpEarned;

  const LessonModel({
    required this.lessonId,
    required this.sectionNumber,
    required this.status,
    this.completedAt,
    required this.practiceCount,
    required this.bestAccuracy,
    required this.totalXpEarned,
  });

  LessonModel copyWith({
    String? status,
    String? completedAt,
    int? practiceCount,
    double? bestAccuracy,
    int? totalXpEarned,
  }) =>
      LessonModel(
        lessonId: lessonId,
        sectionNumber: sectionNumber,
        status: status ?? this.status,
        completedAt: completedAt ?? this.completedAt,
        practiceCount: practiceCount ?? this.practiceCount,
        bestAccuracy: bestAccuracy ?? this.bestAccuracy,
        totalXpEarned: totalXpEarned ?? this.totalXpEarned,
      );

  factory LessonModel.fromMap(Map<String, dynamic> map) => LessonModel(
        lessonId: map['lessonId'] as String,
        sectionNumber: (map['sectionNumber'] as num).toInt(),
        status: map['status'] as String,
        completedAt: map['completedAt'] as String?,
        practiceCount: (map['practiceCount'] as num?)?.toInt() ?? 0,
        bestAccuracy: (map['bestAccuracy'] as num?)?.toDouble() ?? 0.0,
        totalXpEarned: (map['totalXpEarned'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'lessonId': lessonId,
        'sectionNumber': sectionNumber,
        'status': status,
        if (completedAt != null) 'completedAt': completedAt,
        'practiceCount': practiceCount,
        'bestAccuracy': bestAccuracy,
        'totalXpEarned': totalXpEarned,
      };
}
