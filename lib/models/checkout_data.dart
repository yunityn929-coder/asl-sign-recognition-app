class CheckoutData {
  final int xpEarned;
  final double accuracyPercent;
  final int durationSeconds;
  final String sessionType; // "learn" | "practice"
  final String lessonId;
  final bool streakExtended;
  final String difficulty; // "easy" | "medium" | "hard" | "n/a"

  const CheckoutData({
    required this.xpEarned,
    required this.accuracyPercent,
    required this.durationSeconds,
    required this.sessionType,
    required this.lessonId,
    required this.streakExtended,
    this.difficulty = 'n/a',
  });
}
