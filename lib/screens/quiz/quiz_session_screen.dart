import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../data/quiz_definitions.dart';
import '../../models/quiz_question.dart';
import '../../services/quiz_service.dart';

const _kQuestionCount = 10;

const _kOptionColors = [
  AppColors.primary,     // blue
  AppColors.secondary,   // green
  AppColors.xpGold,      // gold
  AppColors.primarySoft, // soft blue
];

const _kOptionTextIsDark = [false, false, false, true];

class QuizSessionScreen extends ConsumerStatefulWidget {
  final QuizSet quizSet;

  const QuizSessionScreen({required this.quizSet, super.key});

  @override
  ConsumerState<QuizSessionScreen> createState() => _QuizSessionScreenState();
}

class _QuizSessionScreenState extends ConsumerState<QuizSessionScreen> {
  late final List<QuizQuestion> _questions;
  final List<String> _wrongSigns = [];

  int _currentIndex = 0;
  int? _selectedOptionIndex;
  bool _answered = false;
  int _score = 0;
  int _correctCount = 0;
  int _timeLeft = 10;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _questions = QuizService.generateQuestions(
      widget.quizSet.signs,
      _kQuestionCount,
      kAvailableSigns,
    );
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft <= 1) {
        timer.cancel();
        setState(() => _timeLeft = 0);
        _submitAnswer(null);
      } else {
        setState(() => _timeLeft--);
      }
    });
  }

  void _submitAnswer(int? index) {
    if (_answered) return;
    _timer?.cancel();
    final question = _questions[_currentIndex];
    final correctIndex = question.options.indexOf(question.correctSign);
    setState(() {
      _answered = true;
      _selectedOptionIndex = index;
      if (index == correctIndex) {
        _score += 10;
        _correctCount++;
      } else {
        _wrongSigns.add(question.correctSign);
      }
    });
    Future.delayed(const Duration(milliseconds: 1500), _advance);
  }

  void _advance() {
    if (!mounted) return;
    if (_currentIndex + 1 < _questions.length) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _selectedOptionIndex = null;
        _timeLeft = 10;
      });
      _startTimer();
    } else {
      context.pushReplacement(
        kRouteQuizResult,
        extra: {
          'score': _correctCount,
          'total': _questions.length,
          'quizSet': widget.quizSet,
          'wrongSigns': _wrongSigns,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[_currentIndex];
    final correctIndex = question.options.indexOf(question.correctSign);
    final isCorrect = _selectedOptionIndex == correctIndex;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              flex: 3,
              child: Center(child: _buildQuestionCard(question)),
            ),
            if (_answered)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  isCorrect ? '✓ Correct! +10 XP' : '✗ Wrong — it was ${question.correctSign}',
                  style: TextStyle(
                    color: isCorrect ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            Expanded(
              flex: 2,
              child: _buildOptionsGrid(question, correctIndex),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Text(
            '${_currentIndex + 1}/${_questions.length}',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          const Icon(Icons.bolt, color: AppColors.xpGold, size: 20),
          const SizedBox(width: 4),
          Text(
            '$_score',
            style: const TextStyle(color: AppColors.xpGold, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          _TimerCircle(timeLeft: _timeLeft),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(QuizQuestion question) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: switch (question.type) {
        QuestionType.imageToLetter => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('$kSignImagePath${question.correctSign}.png', height: 200),
              const SizedBox(height: 16),
              const Text(
                'What letter is this?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ],
          ),
        QuestionType.letterToImage => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                question.correctSign,
                style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                "Which sign shows '${question.correctSign}'?",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ],
          ),
        QuestionType.letterToLetter => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                question.correctSign,
                style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              const Text(
                'What letter is this sign?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ],
          ),
      },
    );
  }

  Widget _buildOptionsGrid(QuizQuestion question, int correctIndex) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildOptionButton(question, 0, correctIndex)),
                const SizedBox(width: 12),
                Expanded(child: _buildOptionButton(question, 1, correctIndex)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildOptionButton(question, 2, correctIndex)),
                const SizedBox(width: 12),
                Expanded(child: _buildOptionButton(question, 3, correctIndex)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton(QuizQuestion question, int index, int correctIndex) {
    final option = question.options[index];
    Color color = _kOptionColors[index];
    Color textColor = _kOptionTextIsDark[index] ? AppColors.textPrimary : Colors.white;
    if (_answered) {
      if (index == correctIndex) {
        color = AppColors.success;
        textColor = Colors.white;
      } else if (index == _selectedOptionIndex) {
        color = AppColors.error;
        textColor = Colors.white;
      } else {
        color = color.withValues(alpha: 0.35);
      }
    }

    final showImage =
        question.type == QuestionType.letterToImage && kAvailableSigns.contains(option);

    return GestureDetector(
      onTap: _answered ? null : () => _submitAnswer(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: showImage
            ? Image.asset('$kSignImagePath$option.png', height: 56)
            : Text(
                option,
                style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}

class _TimerCircle extends StatelessWidget {
  final int timeLeft;

  const _TimerCircle({required this.timeLeft});

  @override
  Widget build(BuildContext context) {
    final color = timeLeft <= 3 ? AppColors.error : AppColors.primary;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        '$timeLeft',
        style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }
}
