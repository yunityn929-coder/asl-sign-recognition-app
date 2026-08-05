class RecognitionResult {
  final String label;
  final double confidence;
  final bool handDetected;
  final List<double> landmarks; // 63 floats (21 landmarks × x,y,z, normalised)

  // Ungated top-2 predictions — unlike label/confidence (blanked below the
  // threshold), these always reflect the raw prediction when a hand is
  // detected, needed by FeedbackService's finer-grained thresholds.
  final String topLabel;
  final double topConfidence;
  final String secondLabel;
  final double secondConfidence;
  final bool isConfident; // topConfidence >= kRecognitionConfidenceThreshold

  // Round-trip time in ms for the processFrame() call that produced this
  // result. -1 if not measured — only used by debug/testing screens.
  final int latencyMs;

  // Only meaningful when handDetected is true, except noHandTimeout which
  // only applies when it's false.
  final bool isTooDark;
  final bool isTooBright;
  final bool handTooClose;
  final bool handTooFar;
  final bool noHandTimeout; // true once ~2s have elapsed since a hand was last seen

  const RecognitionResult({
    required this.label,
    required this.confidence,
    required this.handDetected,
    required this.landmarks,
    required this.topLabel,
    required this.topConfidence,
    required this.secondLabel,
    required this.secondConfidence,
    required this.isConfident,
    this.latencyMs = -1,
    this.isTooDark = false,
    this.isTooBright = false,
    this.handTooClose = false,
    this.handTooFar = false,
    this.noHandTimeout = false,
  });

  RecognitionResult copyWith({
    int? latencyMs,
    bool? isTooDark,
    bool? isTooBright,
    bool? handTooClose,
    bool? handTooFar,
    bool? noHandTimeout,
  }) {
    return RecognitionResult(
      label: label,
      confidence: confidence,
      handDetected: handDetected,
      landmarks: landmarks,
      topLabel: topLabel,
      topConfidence: topConfidence,
      secondLabel: secondLabel,
      secondConfidence: secondConfidence,
      isConfident: isConfident,
      latencyMs: latencyMs ?? this.latencyMs,
      isTooDark: isTooDark ?? this.isTooDark,
      isTooBright: isTooBright ?? this.isTooBright,
      handTooClose: handTooClose ?? this.handTooClose,
      handTooFar: handTooFar ?? this.handTooFar,
      noHandTimeout: noHandTimeout ?? this.noHandTimeout,
    );
  }
}
