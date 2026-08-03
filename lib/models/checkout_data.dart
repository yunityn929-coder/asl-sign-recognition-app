class CheckoutData {
  final int xpEarned;
  final double accuracyPercent;
  final int durationSeconds;
  final String sessionType; // "learn" | "practice"
  final String lessonId;
  final bool streakJustExtended;
  final bool questNewlyCompleted;
  final String difficulty; // "easy" | "medium" | "hard" | "n/a"
  final int correctCount;
  final int totalCount;
  final bool medalNewlyEarned;
  // Set to the tier (1, 2, or 3) reached this session, when earning a medal
  // pushed the medal count for [difficulty] across a badge-tier threshold.
  // Null when no tier was newly reached.
  final int? badgeTierJustReached;

  const CheckoutData({
    required this.xpEarned,
    required this.accuracyPercent,
    required this.durationSeconds,
    required this.sessionType,
    required this.lessonId,
    required this.streakJustExtended,
    required this.questNewlyCompleted,
    this.difficulty = 'n/a',
    required this.correctCount,
    required this.totalCount,
    this.medalNewlyEarned = false,
    this.badgeTierJustReached,
  });
}
