import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/lesson_question_generator.dart';

/// Displays a text-based lesson question (a word, a name, a random-number
/// prompt) in place of the single-sign hand-model card, with a per-sign
/// sequence-progress row when the question spans more than one sign.
class QuestionTextCard extends StatelessWidget {
  final LessonQuestion question;
  final int sequenceIndex;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onHint;

  const QuestionTextCard({
    super.key,
    required this.question,
    required this.sequenceIndex,
    required this.onPrevious,
    required this.onNext,
    required this.onHint,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 260,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Color(0x15000000), blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  question.displayText ?? '',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (question.isMultiSign) ...[
                const SizedBox(height: 16),
                _SequenceRow(signs: question.signSequence, currentIndex: sequenceIndex),
              ],
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded),
                      color: onPrevious != null ? AppColors.primary : AppColors.textSecondary,
                      iconSize: 24,
                      onPressed: onPrevious,
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded),
                      color: onNext != null ? AppColors.primary : AppColors.textSecondary,
                      iconSize: 24,
                      onPressed: onNext,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: onHint,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black12)],
              ),
              child: const Icon(
                Icons.lightbulb_outline_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SequenceRow extends StatelessWidget {
  final List<String> signs;
  final int currentIndex;
  const _SequenceRow({required this.signs, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (int i = 0; i < signs.length; i++)
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: i < currentIndex
                  ? AppColors.primarySoft
                  : i == currentIndex
                      ? AppColors.primary
                      : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              signs[i],
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: i < currentIndex
                    ? AppColors.primary
                    : i == currentIndex
                        ? Colors.white
                        : AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
