import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../data/lesson_definitions.dart';
import '../../models/lesson_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lesson_provider.dart';
import '../../providers/user_provider.dart';

// S-11 — Mode Select
class ModeSelectScreen extends ConsumerWidget {
  final String lessonId;
  const ModeSelectScreen({required this.lessonId, super.key});

  LessonDefinition get _def => kLessons.firstWhere(
        (l) => l.id == lessonId,
        orElse: () =>
            const LessonDefinition(id: '', section: 0, title: '', signs: []),
      );

  LessonModel? _findProgress(List<LessonModel> lessons) {
    for (final l in lessons) {
      if (l.lessonId == lessonId) return l;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: uid == null
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(context, ref, uid),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, String uid) {
    final lessonsAsync = ref.watch(lessonProvider(uid));
    final userAsync = ref.watch(userProvider(uid));

    return lessonsAsync.when(
      data: (lessons) {
        final progress = _findProgress(lessons);
        final practiceUnlocked = progress?.practiceUnlocked ?? false;
        final lastSignIndex = progress?.lastSignIndex ?? 0;
        final user = userAsync.value;
        return _buildContent(context, user, practiceUnlocked, lastSignIndex);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Failed to load lesson')),
    );
  }

  Widget _buildContent(BuildContext context, UserModel? user,
      bool practiceUnlocked, int lastSignIndex) {
    return Column(
      children: [
        _Header(title: _def.title),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const SizedBox(height: 24),
              _ModeCard(
                borderColor: AppColors.primary,
                title: 'Learn Mode',
                description:
                    'Study each sign with camera practice',
                onTap: () => context.push('/lesson/$lessonId/exercise'),
              ),
              const SizedBox(height: 16),
              _ModeCard(
                borderColor:
                    practiceUnlocked ? AppColors.secondary : const Color(0xFFE0E0E0),
                title: 'Practice Mode',
                description:
                    'Test yourself with different difficulty levels',
                locked: !practiceUnlocked,
                lockedMessage: 'Learn the signs to unlock practice',
                onTap: practiceUnlocked
                    ? () => context.push('/lesson/$lessonId/practice/setup')
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final Color borderColor;
  final String title;
  final String description;
  final bool locked;
  final String? lockedMessage;
  final VoidCallback? onTap;

  const _ModeCard({
    required this.borderColor,
    required this.title,
    required this.description,
    this.locked = false,
    this.lockedMessage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: locked
                              ? AppColors.textSecondary
                              : AppColors.textPrimary)),
                ),
                if (locked)
                  const Icon(Icons.lock_outline, color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              locked ? (lockedMessage ?? '') : description,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
