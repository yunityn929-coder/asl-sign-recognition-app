class RecognitionResult {
  final String label;
  final double confidence;
  final bool handDetected;
  final List<double> landmarks; // 42 floats (21 landmarks × x,y only, normalised)

  const RecognitionResult({
    required this.label,
    required this.confidence,
    required this.handDetected,
    required this.landmarks,
  });
}
