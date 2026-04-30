// TFLite class index → ASL label (36 classes: A–Z then 0–9)
const List<String> kSignLabels = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', // 0–9
  'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', // 10–19
  'U', 'V', 'W', 'X', 'Y', 'Z',                       // 20–25
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',  // 26–35
];

const double kRecognitionConfidenceThreshold = 0.85;
