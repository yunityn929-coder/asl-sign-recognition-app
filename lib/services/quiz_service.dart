import 'dart:math';

import '../models/quiz_question.dart';

const Set<String> kAvailableSigns = {
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
  'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
  'U', 'V', 'W', 'X', 'Y', 'Z',
};

const String kSignImagePath = 'assets/models/3d/';

class QuizService {
  static List<QuizQuestion> generateQuestions(
    List<String> signs,
    int count,
    Set<String> availableImages,
  ) {
    final random = Random();
    final shuffled = List<String>.from(signs)..shuffle(random);
    final chosen = shuffled.take(min(count, shuffled.length)).toList();

    return [
      for (final sign in chosen) _buildQuestion(sign, signs, availableImages, random),
    ];
  }

  static QuizQuestion _buildQuestion(
    String correctSign,
    List<String> pool,
    Set<String> availableImages,
    Random random,
  ) {
    final otherSignsWithImages =
        pool.where((s) => s != correctSign && availableImages.contains(s)).length;
    final canUseImages =
        availableImages.contains(correctSign) && otherSignsWithImages >= 3;

    final type = canUseImages
        ? (random.nextBool() ? QuestionType.imageToLetter : QuestionType.letterToImage)
        : QuestionType.letterToLetter;

    final wrongOptions =
        (pool.where((s) => s != correctSign).toList()..shuffle(random)).take(3).toList();
    final options = [correctSign, ...wrongOptions]..shuffle(random);

    return QuizQuestion(
      correctSign: correctSign,
      options: options,
      type: type,
    );
  }
}
