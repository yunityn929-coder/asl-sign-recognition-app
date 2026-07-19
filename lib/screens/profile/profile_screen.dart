import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../data/lesson_definitions.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lesson_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';

const List<String> _kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _formatDate(String isoString) {
  try {
    final date = DateTime.parse(isoString);
    return '${_kMonthNames[date.month - 1]} ${date.year}';
  } catch (_) {
    return '';
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: authAsync.when(
        data: (firebaseUser) {
          if (firebaseUser == null) {
            return const Center(
              child: Text(
                'Not signed in',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
            );
          }
          return _ProfileContent(
            uid: firebaseUser.uid,
            photoUrl: firebaseUser.photoURL,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.uid, required this.photoUrl});
  final String uid;
  final String? photoUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider(uid));
    final lessonsAsync = ref.watch(lessonProvider(uid));

    if (userAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final user = userAsync.asData?.value;

    int signsLearned = lessonsAsync.maybeWhen(
      data: (lessons) {
        final completedLessons =
            lessons.where((l) => l.status == 'completed').toList();
        var total = 0;
        for (final lesson in completedLessons) {
          final def = kLessons.firstWhere(
            (d) => d.id == lesson.lessonId,
            orElse: () =>
                const LessonDefinition(id: '', section: 0, title: '', signs: []),
          );
          total += def.signs.length;
        }
        return total;
      },
      orElse: () => 0,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          _IdCard(user: user, photoUrl: photoUrl),
          const SizedBox(height: 28),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Your Progress',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ProgressCard(user: user, signsLearned: signsLearned),
          ),
          if (user != null && !user.isAnonymous) ...[
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primarySoft),
                ),
                child: ListTile(
                  leading:
                      const Icon(Icons.check_circle, color: AppColors.success),
                  title: Text(user.displayName),
                  subtitle: Text(user.email),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const _SignOutButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _IdCard extends StatelessWidget {
  const _IdCard({required this.user, required this.photoUrl});
  final UserModel? user;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final isAnonymous = user?.isAnonymous ?? true;

    return Container(
      margin: const EdgeInsets.only(top: 16, left: 20, right: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isAnonymous ? const Color(0xFFF5F5F5) : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAnonymous ? const Color(0xFFCCCCCC) : AppColors.primary,
          width: 1.5,
        ),
      ),
      child: isAnonymous
          ? _buildAnonymousContent(context)
          : _buildSignedInContent(),
    );
  }

  Widget _buildAnonymousContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Color(0xFFE0E0E0),
              child: Icon(Icons.person_outline,
                  size: 36, color: Color(0xFF9E9E9E)),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guest User',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Sign in to save your progress',
                  style: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => context.push(kRouteSocialSignIn),
                child: const Text('Create Profile'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => context.push(kRouteSocialSignIn),
                child: const Text('Sign In'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignedInContent() {
    final user = this.user!;
    final firstLetter =
        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?';

    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.primary,
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
          child: photoUrl == null
              ? Text(
                  firstLetter,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.email,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                'Member since ${_formatDate(user.createdAt)}',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.user, required this.signsLearned});
  final UserModel? user;
  final int signsLearned;

  @override
  Widget build(BuildContext context) {
    final totalXp = user?.totalXp ?? 0;
    final longestStreak = user?.longestStreak ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ProgressStat(
                emoji: '⚡', value: '$totalXp', label: 'XP'),
          ),
          const _ProgressDivider(),
          Expanded(
            child: _ProgressStat(
                emoji: '🔥', value: '$longestStreak', label: 'Best Streak'),
          ),
          const _ProgressDivider(),
          Expanded(
            child: _ProgressStat(
                emoji: '✋', value: '$signsLearned', label: 'Signs Learned'),
          ),
        ],
      ),
    );
  }
}

class _ProgressDivider extends StatelessWidget {
  const _ProgressDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 40, color: AppColors.primarySoft);
}

class _ProgressStat extends StatelessWidget {
  const _ProgressStat(
      {required this.emoji, required this.value, required this.label});
  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: TextButton(
        onPressed: () async {
          await ref.read(authServiceProvider).signOut();
          if (context.mounted) context.go(kRouteSplash);
        },
        child: const Text(
          'Sign out',
          style: TextStyle(
            color: AppColors.error,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
