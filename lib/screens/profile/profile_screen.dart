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

    final lessonsCompleted = lessonsAsync.maybeWhen(
      data: (lessons) => lessons.where((l) => l.status == 'completed').length,
      orElse: () => 0,
    );
    final totalLessons = kLessons.length;

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
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.7,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ProgressCard(
              user: user,
              lessonsCompleted: lessonsCompleted,
              totalLessons: totalLessons,
            ),
          ),
          if (user != null && !user.isAnonymous) ...[
            const SizedBox(height: 28),
            const _SignOutButton(),
          ],
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
                  '...',
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
                onPressed: () => context.push(kRouteSocialSignIn, extra: true),
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
                onPressed: () => context.push(kRouteSocialSignIn, extra: false),
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
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.user,
    required this.lessonsCompleted,
    required this.totalLessons,
  });

  final UserModel? user;
  final int lessonsCompleted;
  final int totalLessons;

  @override
  Widget build(BuildContext context) {
    final totalXp = user?.totalXp ?? 0;
    final currentStreak = user?.currentStreak ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              iconWidget: const Text('✦', style: TextStyle(color: AppColors.xpGold, fontSize: 22)),
              value: '$totalXp',
              label: 'Total XP',
            ),
          ),
          Expanded(
            child: _StatItem(
              iconWidget: Icon(
                Icons.local_fire_department_rounded,
                color: currentStreak > 0 ? Colors.orange : AppColors.textSecondary,
                size: 22,
              ),
              value: '$currentStreak',
              label: 'Day Streak',
            ),
          ),
          Expanded(
            child: _StatItem(
              iconWidget: const Icon(Icons.menu_book_rounded, color: AppColors.success, size: 22),
              value: '$lessonsCompleted/$totalLessons',
              label: 'Lessons Done',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.iconWidget,
    required this.value,
    required this.label,
  });

  final Widget iconWidget;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        iconWidget,
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Sign Out?'),
              content: const Text('Are you sure you want to sign out?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
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
