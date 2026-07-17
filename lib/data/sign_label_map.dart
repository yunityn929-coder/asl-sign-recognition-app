// TFLite class index → ASL label (36 classes: 0–9 then A–Z, per sklearn
// LabelEncoder's alphabetical sort — digits precede uppercase letters).
const List<String> kSignLabels = [
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', // 0–9
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', // 10–19
  'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', // 20–29
  'U', 'V', 'W', 'X', 'Y', 'Z',                       // 30–35
];

const double kRecognitionConfidenceThreshold = 0.85;
