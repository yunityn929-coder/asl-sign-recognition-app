import 'dart:math';

import '../data/lesson_definitions.dart';

class LessonQuestion {
  final List<String> signSequence;
  final String? displayText;

  const LessonQuestion({required this.signSequence, this.displayText});

  bool get isMultiSign => signSequence.length > 1;
}

class LessonQuestionGenerator {
  static final Random _rng = Random();

  static List<LessonQuestion> generate(LessonDefinition lesson, {String? userName}) {
    switch (lesson.contentType) {
      case LessonContentType.words:
        return lesson.words
            .map((w) => LessonQuestion(signSequence: w.split(''), displayText: w))
            .toList();

      case LessonContentType.nameEntry:
        final name = (userName ?? '').toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
        if (name.isEmpty) {
          return const [LessonQuestion(signSequence: ['A'], displayText: 'A')];
        }
        return [LessonQuestion(signSequence: name.split(''), displayText: name)];

      case LessonContentType.randomSingle:
        return List.generate(5, (_) {
          final d = _rng.nextInt(10).toString();
          return LessonQuestion(signSequence: [d]);
        });

      case LessonContentType.randomPair:
        return List.generate(5, (_) {
          final a = _rng.nextInt(10);
          final b = _rng.nextInt(10);
          return LessonQuestion(
            signSequence: [a.toString(), b.toString()],
            displayText: '$a  →  $b',
          );
        });

      case LessonContentType.randomExpression:
        return List.generate(5, (_) {
          final a = _rng.nextInt(10);
          // b is bounded so a + b never exceeds 9 (single-digit target sign).
          final b = _rng.nextInt(10 - a);
          final sum = a + b;
          return LessonQuestion(
            signSequence: [sum.toString()],
            displayText: '$a + $b = ?',
          );
        });

      case LessonContentType.signs:
        return lesson.signs.map((s) => LessonQuestion(signSequence: [s])).toList();
    }
  }
}
