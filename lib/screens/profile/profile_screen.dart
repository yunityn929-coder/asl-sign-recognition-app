import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lesson_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';

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
            return const _CenteredMessage(text: 'Not signed in');
          }
          return _ProfileContent(
            uid: firebaseUser.uid,
            photoUrl: firebaseUser.photoURL,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _CenteredMessage(text: 'Something went wrong'),
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

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const _CenteredMessage(text: 'Profile not found');
        }
        final completedCount = lessonsAsync.maybeWhen(
          data: (lessons) =>
              lessons.where((l) => l.status == 'completed').length,
          orElse: () => 0,
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileHeader(user: user, photoUrl: photoUrl),
              const SizedBox(height: 28),
              _StatsRow(user: user, lessonsCompleted: completedCount),
              const SizedBox(height: 28),
              _SignAccuracySection(signAccuracy: user.signAccuracy),
              const SizedBox(height: 28),
              _AccountSection(user: user),
              const SizedBox(height: 28),
              const _SignOutButton(),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _CenteredMessage(text: 'Something went wrong'),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user, required this.photoUrl});
  final UserModel user;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final isAnonymous = user.isAnonymous;
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: isAnonymous
              ? AppColors.textSecondary.withValues(alpha: 0.2)
              : AppColors.primary,
          backgroundImage: !isAnonymous && photoUrl != null
              ? NetworkImage(photoUrl!)
              : null,
          child: isAnonymous
              ? const Icon(Icons.person,
                  size: 40, color: AppColors.textSecondary)
              : (photoUrl == null
                  ? Text(
                      user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null),
        ),
        const SizedBox(height: 12),
        Text(
          user.displayName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isAnonymous ? 'Guest User' : user.email,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.user, required this.lessonsCompleted});
  final UserModel user;
  final int lessonsCompleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
                emoji: '⚡', value: '${user.totalXp}', label: 'XP'),
          ),
          const _StatDivider(),
          Expanded(
            child: _StatItem(
                emoji: '🔥', value: '${user.currentStreak}', label: 'Streak'),
          ),
          const _StatDivider(),
          Expanded(
            child: _StatItem(
                emoji: '📚', value: '$lessonsCompleted', label: 'Lessons'),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 40, color: AppColors.primarySoft);
}

class _StatItem extends StatelessWidget {
  const _StatItem(
      {required this.emoji, required this.value, required this.label});
  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
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

class _SignAccuracySection extends StatelessWidget {
  const _SignAccuracySection({required this.signAccuracy});
  final Map<String, double> signAccuracy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sign Accuracy',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (signAccuracy.isEmpty)
          const Text(
            'Complete lessons to see your accuracy',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          )
        else
          _buildBadges(),
      ],
    );
  }

  Widget _buildBadges() {
    final sorted = signAccuracy.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();
    final remaining = sorted.length > 5 ? sorted.sublist(5) : <MapEntry<String, double>>[];
    final bottom =
        remaining.length <= 3 ? remaining : remaining.sublist(remaining.length - 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: top
              .map((e) => _AccuracyBadge(
                  sign: e.key, accuracy: e.value, color: AppColors.success))
              .toList(),
        ),
        if (bottom.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: bottom
                .map((e) => _AccuracyBadge(
                    sign: e.key, accuracy: e.value, color: AppColors.error))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _AccuracyBadge extends StatelessWidget {
  const _AccuracyBadge(
      {required this.sign, required this.accuracy, required this.color});
  final String sign;
  final double accuracy;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            sign.isNotEmpty ? sign[0].toUpperCase() : '?',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            '${(accuracy * 100).round()}%',
            style: TextStyle(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Account',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primarySoft),
          ),
          child: user.isAnonymous
              ? ListTile(
                  leading:
                      const Icon(Icons.login, color: AppColors.primary),
                  title: const Text('Link Google Account'),
                  subtitle: const Text('Save your progress'),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
                  onTap: () => context.push(kRouteSocialSignIn),
                )
              : ListTile(
                  leading:
                      const Icon(Icons.check_circle, color: AppColors.success),
                  title: Text(user.displayName),
                  subtitle: Text(user.email),
                ),
        ),
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

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          text,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
        ),
      );
}
