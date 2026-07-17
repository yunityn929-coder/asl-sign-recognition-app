class RecognitionResult {
  final String label;
  final double confidence;
  final bool handDetected;
  final List<double> landmarks; // 63 floats (21 landmarks × x,y,z, normalised)

  // Ungated top-2 predictions. Unlike label/confidence (blanked to '' / 0
  // below kRecognitionConfidenceThreshold for backward compatibility),
  // these always reflect the raw softmax argmax/runner-up whenever a hand
  // is detected — needed by FeedbackService's finer-grained thresholds.
  final String topLabel;
  final double topConfidence;
  final String secondLabel;
  final double secondConfidence;
  final bool isConfident; // topConfidence >= kRecognitionConfidenceThreshold

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
  });
}
