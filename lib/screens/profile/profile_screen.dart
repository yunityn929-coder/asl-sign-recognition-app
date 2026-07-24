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
import '../../services/firestore_service.dart';

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
            isAnonymous: firebaseUser.isAnonymous,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.uid, required this.isAnonymous});
  final String uid;
  final bool isAnonymous;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider(uid));
    final lessonsAsync = ref.watch(lessonProvider(uid));

    if (userAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final user = userAsync.asData?.value;

    // Firebase Auth can go non-anonymous (e.g. linkWithCredential succeeding
    // in the background) before the Firestore user doc's updateUser() call
    // confirms it — or if that call never completes. Only show the signed-in
    // ID card once both agree; otherwise treat the state as still-guest
    // rather than flipping to signed-in on a half-confirmed link.
    final confirmedSignedIn = !isAnonymous && user?.isAnonymous == false;

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
          const _SectionLabel('Account'),
          const SizedBox(height: 12),
          _IdCard(user: user, isAnonymous: !confirmedSignedIn),
          const SizedBox(height: 28),
          const _SectionLabel('Your Progress'),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ProgressCard(
              user: user,
              lessonsCompleted: lessonsCompleted,
              totalLessons: totalLessons,
            ),
          ),
          const SizedBox(height: 28),
          const _SectionLabel('Badges'),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _BadgesCard(medalsEarned: user?.medalsEarned ?? const {}),
          ),
          if (confirmedSignedIn) ...[
            const SizedBox(height: 28),
            const _SignOutButton(),
            const SizedBox(height: 12),
            const _DeleteAccountButton(),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.7,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _IdCard extends StatelessWidget {
  const _IdCard({required this.user, required this.isAnonymous});
  final UserModel? user;
  final bool isAnonymous;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
          : (user == null ? _buildLoadingContent() : _buildSignedInContent()),
    );
  }

  Widget _buildLoadingContent() {
    return const SizedBox(
      height: 84,
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
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
                onPressed: () => context.push(kRouteLinkAccount),
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
                onPressed: () => context.push(kRouteSignIn),
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
          backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
          child: user.photoUrl.isEmpty
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
              value: '$totalXp',
              label: 'Total XP',
            ),
          ),
          Expanded(
            child: _StatItem(
              value: '$currentStreak',
              label: 'Day Streak',
            ),
          ),
          Expanded(
            child: _StatItem(
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
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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

const List<int> _kBadgeTiers = [5, 10, 20];

class _MedalKind {
  final String difficulty;
  final Color color;
  final String title;
  final String owlAsset;
  final String medalName;
  const _MedalKind(this.difficulty, this.color, this.title, this.owlAsset, this.medalName);
}

const List<_MedalKind> _kMedalKinds = [
  _MedalKind('easy', AppColors.medalBronze, 'Skilled Signer', 'owl_student', 'Bronze'),
  _MedalKind('medium', AppColors.medalSilver, 'Expert Signer', 'owl_expert', 'Silver'),
  _MedalKind('hard', AppColors.medalGold, 'Master Signer', 'owl_master', 'Gold'),
];

class _BadgesCard extends StatelessWidget {
  const _BadgesCard({required this.medalsEarned});
  final Map<String, bool> medalsEarned;

  int _countFor(String difficulty) => medalsEarned.entries
      .where((e) => e.value && e.key.endsWith('_$difficulty'))
      .length;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final kind in _kMedalKinds)
            Expanded(
              child: _BadgeColumn(kind: kind, count: _countFor(kind.difficulty)),
            ),
        ],
      ),
    );
  }
}

class _BadgeColumn extends StatelessWidget {
  const _BadgeColumn({required this.kind, required this.count});
  final _MedalKind kind;
  final int count;

  static const _lockedColor = Color(0xFFD0D0D0);
  static const _tier1Color = Color(0xFFFDFAE5);
  static const _tier2Color = Color(0xFFBCE2ED);
  static const _tier3Color = Color(0xFFFFE2E8);

  static Color _tierBackground(int count) {
    if (count >= 20) return _tier3Color;
    if (count >= 10) return _tier2Color;
    if (count >= 5) return _tier1Color;
    return _lockedColor;
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = count >= _kBadgeTiers.first;
    final mastered = count >= _kBadgeTiers.last;
    final nextThreshold =
        _kBadgeTiers.firstWhere((t) => count < t, orElse: () => _kBadgeTiers.last);
    final textColor = unlocked ? kind.color : _lockedColor;
    final bgColor = _tierBackground(count);

    return GestureDetector(
      onTap: () => _showBadgeInfoDialog(context, unlocked, mastered, nextThreshold),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BadgeCircleIcon(
            color: bgColor,
            owlAsset: kind.owlAsset,
            unlocked: unlocked,
            mastered: mastered,
          ),
          const SizedBox(height: 8),
          Text(
            kind.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: unlocked ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$count/$nextThreshold',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
          ),
        ],
      ),
    );
  }

  void _showBadgeInfoDialog(
    BuildContext context,
    bool unlocked,
    bool mastered,
    int nextThreshold,
  ) {
    final medalWord = kind.medalName.toLowerCase();
    final message = mastered
        ? "You've collected $count $medalWord medals and fully mastered the "
            '${kind.title} badge!'
        : 'Collect ${nextThreshold - count} more $medalWord '
            "medal${nextThreshold - count == 1 ? '' : 's'} to "
            '${unlocked ? 'move to the next tier' : 'unlock this badge'}.';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(kind.title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _BadgeCircleIcon extends StatelessWidget {
  const _BadgeCircleIcon({
    required this.color,
    required this.owlAsset,
    required this.unlocked,
    required this.mastered,
  });
  final Color color;
  final String owlAsset;
  final bool unlocked;
  final bool mastered;

  static const double _diameter = 52;
  static const double _border = 4;
  static const double _padding = 4;

  // Standard luminance-weighted greyscale matrix, used to dim the owl
  // artwork when its tier hasn't been unlocked yet.
  static const List<double> _greyscaleMatrix = [
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    final owlImage = Image.asset(
      'assets/images/$owlAsset.png',
      width: _diameter - 2 * _border - 2 * _padding,
      height: _diameter - 2 * _border - 2 * _padding,
      fit: BoxFit.contain,
    );

    return SizedBox(
      width: _diameter + 4,
      height: _diameter + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: _diameter,
            height: _diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: Colors.white, width: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: unlocked
                  ? owlImage
                  : Opacity(
                      opacity: 0.55,
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.matrix(_greyscaleMatrix),
                        child: owlImage,
                      ),
                    ),
            ),
          ),
          if (mastered)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x33000000), blurRadius: 2, offset: Offset(0, 1)),
                  ],
                ),
                child: const Icon(Icons.workspace_premium,
                    size: 13, color: AppColors.medalGold),
              ),
            ),
        ],
      ),
    );
  }
}

class _SignOutButton extends ConsumerStatefulWidget {
  const _SignOutButton();

  @override
  ConsumerState<_SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends ConsumerState<_SignOutButton> {
  bool _loading = false;

  Future<void> _onTap() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
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

      // Capture before signOut() runs: it flips authStateProvider to null,
      // which removes this button (and this State) from the tree — router
      // must not depend on context/ref surviving that.
      final authService = ref.read(authServiceProvider);
      // ignore: use_build_context_synchronously
      final router = GoRouter.of(context);
      await authService.signOut();
      router.go(kRouteSplash);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: _loading ? null : _onTap,
        child: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
              )
            : const Text(
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

class _DeleteAccountButton extends ConsumerStatefulWidget {
  const _DeleteAccountButton();

  @override
  ConsumerState<_DeleteAccountButton> createState() => _DeleteAccountButtonState();
}

class _DeleteAccountButtonState extends ConsumerState<_DeleteAccountButton> {
  bool _loading = false;

  Future<void> _onTap() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Account?'),
          content: const Text(
            'This permanently deletes your account and progress. '
            "Action can't be undone.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      final uid = ref.read(authStateProvider).value?.uid;
      if (uid == null) return;

      // Capture everything needed before any operation below runs: deleting
      // the Firestore doc flips the Profile screen's confirmed-signed-in
      // check, which removes this button from the tree and disposes this
      // State mid-flight — ref/context are unusable the instant that
      // happens, so nothing after this point can depend on them directly.
      final authService = ref.read(authServiceProvider);
      final firestoreService = ref.read(firestoreServiceProvider);
      // ignore: use_build_context_synchronously
      final router = GoRouter.of(context);
      // ignore: use_build_context_synchronously
      final messenger = ScaffoldMessenger.of(context);

      try {
        debugPrint('[TEMP DEBUG] DeleteAccountButton: calling reauthenticateForDeleteIfNeeded');
        await authService.reauthenticateForDeleteIfNeeded();
        debugPrint('[TEMP DEBUG] DeleteAccountButton: reauthenticateForDeleteIfNeeded done, calling deleteUserData');
        await firestoreService.deleteUserData(uid);
        debugPrint('[TEMP DEBUG] DeleteAccountButton: deleteUserData done, calling deleteAccount');
        await authService.deleteAccount();
        debugPrint('[TEMP DEBUG] DeleteAccountButton: deleteAccount done, navigating to splash');
        router.go(kRouteSplash);
      } catch (e, st) {
        debugPrint('[TEMP DEBUG] DeleteAccountButton: caught error: $e\n$st');
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: _loading ? null : _onTap,
        child: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
              )
            : const Text(
                'Delete Account',
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
