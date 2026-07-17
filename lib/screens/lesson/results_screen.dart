import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/xp_constants.dart';
import '../../data/lesson_definitions.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lesson_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/tts_service.dart';
import 'widgets/results_widgets.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  final String lessonId;
  final int correctCount;
  final int totalCount;
  final List<String> missedSigns;

  const ResultsScreen({
    super.key,
    required this.lessonId,
    required this.correctCount,
    required this.totalCount,
    required this.missedSigns,
  });

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  bool _initialized = false;

  int get _xpEarned => widget.correctCount * kXpLearnCorrect;

  String? get _nextLessonId {
    final idx = kLessons.indexWhere((l) => l.id == widget.lessonId);
    if (idx >= 0 && idx < kLessons.length - 1) return kLessons[idx + 1].id;
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    try {
      await Future.wait([
        ref.read(lessonActionsProvider(uid)).markLessonComplete(widget.lessonId),
        ref.read(userActionsProvider(uid)).addXp(_xpEarned),
      ]);
    } catch (_) {}
    if (mounted) {
      ref
          .read(ttsServiceProvider)
          .speak('Lesson complete! You earned $_xpEarned XP');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildContent(),
              ),
            ),
            _buildButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 60),
        ResultHeader(
            correctCount: widget.correctCount, totalCount: widget.totalCount),
        const SizedBox(height: 32),
        ResultScoreCard(
          correctCount: widget.correctCount,
          totalCount: widget.totalCount,
          xpEarned: _xpEarned,
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            '✦ +$_xpEarned XP added to your account',
            style: const TextStyle(fontSize: 14, color: Color(0xFF888888)),
          ),
        ),
        if (widget.missedSigns.isNotEmpty) ...[
          const SizedBox(height: 24),
          ResultMissedSignsRow(missedSigns: widget.missedSigns),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    final nextId = _nextLessonId;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 0, 24, MediaQuery.of(context).padding.bottom + 32),
      child: Column(
        children: [
          _PrimaryButton(
            label: nextId != null ? 'Next Lesson →' : 'Back to Home',
            onTap: () {
              if (nextId != null) {
                context.pushReplacement('/lesson/$nextId/exercise');
              } else {
                context.go('/home');
              }
            },
          ),
          const SizedBox(height: 12),
          _SecondaryButton(
            onTap: () => context
                .pushReplacement('/lesson/${widget.lessonId}/exercise'),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFFFD166),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFFC9962A), offset: Offset(0, 4), blurRadius: 0),
          ],
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111))),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SecondaryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('Practise again',
              style: TextStyle(fontSize: 15, color: Color(0xFF666666))),
        ),
      ),
    );
  }
}
