import 'package:flutter/material.dart';

import '../../data/quiz_definitions.dart';

// Quiz Result — TODO: full results UI
class QuizResultScreen extends StatelessWidget {
  final int score;
  final int total;
  final QuizSet? quizSet;
  final List<String> wrongSigns;

  const QuizResultScreen({
    required this.score,
    required this.total,
    required this.quizSet,
    required this.wrongSigns,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Quiz Result — TODO ($score/$total)')),
    );
  }
}
