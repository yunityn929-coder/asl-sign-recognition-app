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

  String _averageAccuracy(UserModel? user) {
    if (user == null || _def.signs.isEmpty) return 'Not attempted';
    final scores = [
      for (final sign in _def.signs)
        if (user.signAccuracy.containsKey(sign)) user.signAccuracy[sign]!,
    ];
    if (scores.isEmpty) return 'Not attempted';
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    return '${(avg * 100).round()}%';
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
        final completed = _findProgress(lessons)?.status == 'completed';
        final user = userAsync.value;
        return _buildContent(context, user, completed);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Failed to load lesson')),
    );
  }

  Widget _buildContent(BuildContext context, UserModel? user, bool completed) {
    return Column(
      children: [
        _Header(title: _def.title),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _LessonInfoCard(
                title: _def.title,
                signCount: _def.signs.length,
                accuracyLabel: _averageAccuracy(user),
              ),
              const SizedBox(height: 24),
              _ModeCard(
                icon: Icons.school_outlined,
                iconColor: AppColors.primary,
                borderColor: AppColors.primary,
                title: 'Learn Mode',
                description:
                    'Study each sign with demonstrations and camera practice',
                badge: !completed ? 'Recommended' : null,
                onTap: () => context.push('/lesson/$lessonId/exercise'),
              ),
              const SizedBox(height: 16),
              _ModeCard(
                icon: Icons.fitness_center_outlined,
                iconColor: completed ? AppColors.secondary : AppColors.textSecondary,
                borderColor:
                    completed ? AppColors.secondary : const Color(0xFFE0E0E0),
                title: 'Practice Mode',
                description:
                    'Test yourself against the clock with difficulty settings',
                locked: !completed,
                lockedMessage: 'Complete Learn Mode first',
                onTap: completed
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
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _LessonInfoCard extends StatelessWidget {
  final String title;
  final int signCount;
  final String accuracyLabel;
  const _LessonInfoCard({
    required this.title,
    required this.signCount,
    required this.accuracyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('$signCount signs',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('Your best accuracy: $accuracyLabel',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final String title;
  final String description;
  final String? badge;
  final bool locked;
  final String? lockedMessage;
  final VoidCallback? onTap;

  const _ModeCard({
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.title,
    required this.description,
    this.badge,
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
                Icon(icon, size: 36, color: locked ? AppColors.textSecondary : iconColor),
                const SizedBox(width: 12),
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
                  const Icon(Icons.lock_outline, color: AppColors.textSecondary)
                else if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.xpGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(badge!,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ),
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
