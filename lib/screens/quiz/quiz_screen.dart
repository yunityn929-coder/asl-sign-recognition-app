import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../data/quiz_definitions.dart';
import '../../models/lesson_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lesson_provider.dart';
import '../../providers/user_provider.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  @override
  Widget build(BuildContext context) {
    return ref.watch(authStateProvider).when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('Sign-in failed. Check your connection.')),
          );
        }
        return _buildScaffold(context, user.uid);
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('Something went wrong.')),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, String uid) {
    final lessonsAsync = ref.watch(lessonProvider(uid));
    final bestScores = ref.watch(userProvider(uid)).value?.quizBestScores ?? {};

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Expanded(
              child: lessonsAsync.when(
                data: (lessons) => _buildList(lessons, bestScores),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(
                  child: Text(
                    'Something went wrong. Try again.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quiz',
              style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<LessonModel> lessons, Map<String, int> bestScores) {
    final sectionQuizzes = kQuizSets.where((q) => q.sectionNumber != 0).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        for (final quizSet in sectionQuizzes) ...[
          _SectionQuizCard(
            quizSet: quizSet,
            bestScore: bestScores[quizSet.id],
            unlocked: _isUnlocked(lessons, quizSet.sectionNumber),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  bool _isUnlocked(List<LessonModel> lessons, int sectionNumber) {
    return lessons.any(
      (l) => l.sectionNumber == sectionNumber && (l.status == 'available' || l.status == 'completed'),
    );
  }
}

class _SectionQuizCard extends StatelessWidget {
  final QuizSet quizSet;
  final int? bestScore;
  final bool unlocked;

  const _SectionQuizCard({required this.quizSet, required this.bestScore, required this.unlocked});

  IconData get _icon {
    switch (quizSet.sectionNumber) {
      case 1:
        return Icons.abc;
      case 2:
        return Icons.spellcheck;
      case 3:
        return Icons.tag;
      default:
        return Icons.quiz;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (unlocked ? AppColors.primary : AppColors.textSecondary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: unlocked ? AppColors.primary : AppColors.textSecondary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quizSet.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: unlocked ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  quizSet.description,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  bestScore != null ? 'Best: $bestScore/10' : 'Not played yet',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: bestScore != null ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          unlocked
              ? ElevatedButton(
                  onPressed: () => context.push(kRouteQuizSession, extra: quizSet),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Play', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                )
              : const Icon(Icons.lock_outline, color: AppColors.textSecondary, size: 22),
        ],
      ),
    );
  }
}
