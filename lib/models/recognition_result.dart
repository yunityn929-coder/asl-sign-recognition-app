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

  // Round-trip time in ms for the processFrame() call that produced this
  // result (MethodChannel → MediaPipe landmark detection → normalise →
  // TFLite inference). -1 if not measured. Added for physical-device
  // performance testing (see lib/screens/debug/recognition_test_screen.dart);
  // not used by production screens.
  final int latencyMs;

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
  });

  RecognitionResult copyWith({int? latencyMs}) {
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
    );
  }
}
