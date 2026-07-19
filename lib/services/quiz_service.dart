import 'dart:math';

import '../models/quiz_question.dart';

const Set<String> kAvailableSigns = {
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
  'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
  'U', 'V', 'W', 'X', 'Y', 'Z',
};

const String kSignImagePath = 'assets/models/3d/';

// Path for unlabeled hand sign images (no answer label)
// Used in quiz to avoid giving away the answer
const String kUnlabeledSignImagePath = 'assets/images/hand_sign/';

// Signs that have unlabeled images available
const Set<String> kUnlabeledSigns = {
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
  'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
  'U', 'V', 'W', 'X', 'Y', 'Z',
};

// Naming convention for unlabeled images:
// digit: hand_0.png, hand_1.png ... hand_9.png
// letter: hand_a.png, hand_b.png ... hand_z.png (lowercase on disk)

String? quizImagePath(String sign) {
  if (kUnlabeledSigns.contains(sign)) {
    // Use unlabeled image — no label visible in quiz
    final name = sign.contains(RegExp(r'[0-9]'))
        ? 'hand_$sign'
        : 'hand_${sign.toLowerCase()}';
    return '$kUnlabeledSignImagePath$name.png';
  }
  if (kAvailableSigns.contains(sign)) {
    // Fall back to labeled 3d model image (only reachable now if a sign
    // isn't in kUnlabeledSigns, which currently covers all of kAvailableSigns)
    return '$kSignImagePath$sign.png';
  }
  return null; // no image available
}

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
