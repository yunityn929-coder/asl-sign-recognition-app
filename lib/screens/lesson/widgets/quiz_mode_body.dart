import 'package:flutter/material.dart';

class QuizModeBody extends StatelessWidget {
  final String sign;
  final List<String> options;
  final String? tappedOption;
  final bool? answerCorrect;
  final bool buttonsDisabled;
  final void Function(String) onAnswerTap;
  final VoidCallback onSkip;

  const QuizModeBody({
    super.key,
    required this.sign,
    required this.options,
    required this.tappedOption,
    required this.answerCorrect,
    required this.buttonsDisabled,
    required this.onAnswerTap,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          height: 260,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x15000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Now sign this:',
                style: TextStyle(fontSize: 16, color: Color(0xFF888888)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                sign,
                style: const TextStyle(
                  fontSize: 96,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111111),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ...options.map((opt) => _AnswerButton(
              option: opt,
              correctSign: sign,
              tappedOption: tappedOption,
              disabled: buttonsDisabled,
              onTap: () => onAnswerTap(opt),
            )),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: buttonsDisabled ? null : onSkip,
            child: const Text(
              'Skip',
              style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _AnswerButton extends StatelessWidget {
  final String option;
  final String correctSign;
  final String? tappedOption;
  final bool disabled;
  final VoidCallback onTap;

  const _AnswerButton({
    required this.option,
    required this.correctSign,
    required this.tappedOption,
    required this.disabled,
    required this.onTap,
  });

  bool get _isCorrect => option == correctSign;
  bool get _wasTapped => tappedOption == option;
  bool get _answered  => tappedOption != null;

  Color get _bg {
    if (!_answered) return Colors.white;
    if (_isCorrect) return const Color(0xFFB0E0A8);
    if (_wasTapped) return const Color(0xFFFFB3B3);
    return Colors.white;
  }

  Color get _border {
    if (!_answered) return const Color(0xFFE0E0E0);
    if (_isCorrect) return const Color(0xFFB0E0A8);
    if (_wasTapped) return const Color(0xFFFFB3B3);
    return const Color(0xFFE0E0E0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        height: 56,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111111),
                ),
              ),
            ),
            if (_isCorrect && _answered)
              const Icon(Icons.check_rounded, color: Color(0xFF4CAF50), size: 22),
          ],
        ),
      ),
    );
  }
}
