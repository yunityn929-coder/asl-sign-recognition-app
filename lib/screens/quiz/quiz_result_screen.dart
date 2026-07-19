import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../data/quiz_definitions.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';

class QuizResultScreen extends ConsumerStatefulWidget {
  final int score;
  final int total;
  final QuizSet quizSet;
  final List<String> wrongSigns;

  const QuizResultScreen({
    required this.score,
    required this.total,
    required this.quizSet,
    required this.wrongSigns,
    super.key,
  });

  @override
  ConsumerState<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends ConsumerState<QuizResultScreen> {
  bool _xpSaved = false;

  int get _xpEarned => widget.score * 10;

  int get _accuracyPercent =>
      widget.total == 0 ? 0 : ((widget.score / widget.total) * 100).round();

  String get _trophyEmoji {
    if (widget.total == 0) return '💪';
    if (widget.score == widget.total) return '🏆';
    final ratio = widget.score / widget.total;
    if (ratio >= 0.8) return '⭐';
    if (ratio >= 0.6) return '👍';
    return '💪';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveXp());
  }

  Future<void> _saveXp() async {
    if (_xpSaved) return;
    _xpSaved = true;
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    try {
      await ref.read(userActionsProvider(uid)).addXp(_xpEarned);
      final existing =
          ref.read(userProvider(uid)).value?.quizBestScores[widget.quizSet.id] ?? 0;
      if (widget.score > existing) {
        await ref
            .read(firestoreServiceProvider)
            .saveQuizBestScore(uid, widget.quizSet.id, widget.score);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(_trophyEmoji, style: const TextStyle(fontSize: 72)),
              const SizedBox(height: 12),
              const Text(
                'Quiz Complete!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                widget.quizSet.title,
                style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              _buildScoreCard(),
              if (widget.wrongSigns.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildWeakSignsSection(context),
              ],
              const Spacer(),
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Column(
        children: [
          Text(
            '${widget.score} / ${widget.total}',
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text(
            '$_accuracyPercent% accuracy',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bolt, color: AppColors.xpGold, size: 20),
              const SizedBox(width: 4),
              Text(
                '+$_xpEarned XP',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.xpGold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeakSignsSection(BuildContext context) {
    final uniqueWrongSigns = widget.wrongSigns.toSet().toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Signs to practice',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final sign in uniqueWrongSigns) _WeakSignBadge(sign: sign),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => context.go(kRouteSigns),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Practice these signs', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.pushReplacement(kRouteQuizSession, extra: widget.quizSet),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Play Again', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => context.go(kRouteHome),
            child: const Text(
              'Back to Quizzes',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeakSignBadge extends StatelessWidget {
  final String sign;
  const _WeakSignBadge({required this.sign});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        sign,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.error),
      ),
    );
  }
}
