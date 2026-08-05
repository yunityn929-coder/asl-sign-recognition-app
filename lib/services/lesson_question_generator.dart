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
        // Pool of 10 digits, shuffled once and the first 5 taken — sampling
        // without replacement, so no digit repeats within a session.
        final singlePool = List.generate(10, (d) => d.toString())..shuffle(_rng);
        return singlePool
            .take(5)
            .map((d) => LessonQuestion(signSequence: [d]))
            .toList();

      case LessonContentType.randomPair:
        // Pool of all 100 ordered (a, b) digit pairs, shuffled once and the
        // first 5 taken — no pair repeats within a session.
        final pairPool = <List<int>>[
          for (var a = 0; a < 10; a++)
            for (var b = 0; b < 10; b++) [a, b],
        ]..shuffle(_rng);
        return pairPool
            .take(5)
            .map((pair) => LessonQuestion(
                  signSequence: [pair[0].toString(), pair[1].toString()],
                  displayText: '${pair[0]}  →  ${pair[1]}',
                ))
            .toList();

      case LessonContentType.randomExpression:
        // Pool of all 55 valid (a, b) pairs where a + b <= 9 (so the target
        // sign stays single-digit), shuffled once and the first 5 taken —
        // no expression repeats within a session.
        final expressionPool = <List<int>>[
          for (var a = 0; a < 10; a++)
            for (var b = 0; b < 10 - a; b++) [a, b],
        ]..shuffle(_rng);
        return expressionPool.take(5).map((pair) {
          final sum = pair[0] + pair[1];
          return LessonQuestion(
            signSequence: [sum.toString()],
            displayText: '${pair[0]} + ${pair[1]} = ?',
          );
        }).toList();

      case LessonContentType.signs:
        return lesson.signs.map((s) => LessonQuestion(signSequence: [s])).toList();
    }
  }
}
