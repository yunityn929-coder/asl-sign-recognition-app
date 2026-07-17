enum QuestionType { imageToLetter, letterToImage, letterToLetter }

class QuizQuestion {
  final String correctSign;
  final List<String> options;
  final QuestionType type;
  final int timeSeconds;

  const QuizQuestion({
    required this.correctSign,
    required this.options,
    required this.type,
    this.timeSeconds = 10,
  });
}
