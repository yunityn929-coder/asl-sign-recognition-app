import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/route_constants.dart';
import '../../data/lesson_definitions.dart';
import '../../models/lesson_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lesson_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';
import 'widgets/path_body.dart';
import 'widgets/unit_banner.dart';

// S-13 — Home
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _fallbackTriggered = false;
  bool _guidanceChecked = false;
  late final ScrollController _scroll;
  final _activeUnit = ValueNotifier<int>(0);
  List<double>? _unitTopYs;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _activeUnit.dispose();
    super.dispose();
  }

  void _onScroll() {
    final ys = _unitTopYs;
    if (ys == null || !_scroll.hasClients) return;
    final offset = _scroll.offset;
    final threshold = offset + MediaQuery.of(context).size.height * 0.005;
    var idx = 0;
    for (var i = 1; i < ys.length; i++) {
      if (ys[i] <= threshold) {
        idx = i;
      } else {
        break;
      }
    }
    if (idx != _activeUnit.value) _activeUnit.value = idx;
  }

  @override
  Widget build(BuildContext context) {
    return ref.watch(authStateProvider).when(
      data: (user) {
        if (user == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Sign-in failed. Check your connection.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await FirebaseAuth.instance.signInAnonymously();
                      } catch (_) {}
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        return _buildScaffold(context, user.uid);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('Something went wrong.')),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, String uid) {
    final userAsync    = ref.watch(userProvider(uid));
    final lessonsAsync = ref.watch(lessonProvider(uid));
    final user         = userAsync.asData?.value;

    if (!_guidanceChecked && user != null) {
      _guidanceChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeShowFirstTimeGuidance(context, uid, user);
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context, user),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StickyUnitBanner(
            activeIndex: _activeUnit,
            sections: kSections,
          ),
          Expanded(
            child: lessonsAsync.when(
              data: (lessons) => _buildBody(context, uid, lessons),
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
    );
  }

  Future<void> _maybeShowFirstTimeGuidance(
      BuildContext context, String uid, UserModel user) async {
    if (user.hasSeenHomeGuidance) return;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Welcome to HiASL',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        content: const Text(
          "Quick tip: if hand-sign recognition doesn't feel accurate for you, "
          "calibrate your signs in Settings. It teaches the camera your hand "
          "shape and lighting so it recognizes you better.",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'later'),
            child: const Text('Got it', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, 'calibrate'),
            child: const Text('Calibrate Now'),
          ),
        ],
      ),
    );

    await ref.read(firestoreServiceProvider).updateUser(uid, {'hasSeenHomeGuidance': true});
    if (result == 'calibrate' && context.mounted) {
      context.push(kRouteCalibrationSettings);
    }
  }

  Widget _buildBody(BuildContext context, String uid, List<LessonModel> lessons) {
    if (lessons.isEmpty && !_fallbackTriggered) {
      _fallbackTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(firestoreServiceProvider).initLessons(uid, 's1l1').catchError((_) {});
      });
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        PathBody(
          lessons: lessons,
          scrollController: _scroll,
          activeUnitNotifier: _activeUnit,
          onUnitPositionsComputed: (ys) => _unitTopYs = ys,
          onLessonTap: (lessonId) {
            context.push('/lesson/$lessonId/mode');
          },
        ),
        Positioned(
          top: 16,
          left: 20,
          child: _QuestButton(onTap: () => context.push(kRouteQuest)),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: _ScrollToTopFab(controller: _scroll),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, UserModel? user) {
    final xp     = user?.totalXp ?? 0;
    final streak = user?.currentStreak ?? 0;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 20,
      title: const Text(
        'HiASL',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w900,
          fontSize: 22,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        _XpBadge(xp: xp),
        const SizedBox(width: 8),
        _StreakBadge(streak: streak, onTap: () => context.go(kRouteStreak)),
        IconButton(
          onPressed: () => context.go(kRouteSettings),
          icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary, size: 22),
          splashRadius: 20,
        ),
      ],
    );
  }
}

class _ScrollToTopFab extends StatefulWidget {
  final ScrollController controller;
  const _ScrollToTopFab({required this.controller});

  @override
  State<_ScrollToTopFab> createState() => _ScrollToTopFabState();
}

class _ScrollToTopFabState extends State<_ScrollToTopFab> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final show = widget.controller.hasClients && widget.controller.offset > 200;
    if (show != _visible) setState(() => _visible = show);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !_visible,
        child: GestureDetector(
          onTap: () => widget.controller.animateTo(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          ),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _XpBadge extends StatelessWidget {
  final int xp;
  const _XpBadge({required this.xp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.xpGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✦', style: TextStyle(color: AppColors.xpGold, fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            '$xp XP',
            style: const TextStyle(
              color: AppColors.xpGold,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int streak;
  final VoidCallback onTap;
  const _StreakBadge({required this.streak, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            color: streak > 0 ? Colors.orange : AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 2),
          Text(
            '$streak',
            style: TextStyle(
              color: streak > 0 ? Colors.orange : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestButton extends StatelessWidget {
  final VoidCallback onTap;
  const _QuestButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.bannerGold,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.bannerGold.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/treasure.png', width: 35, height: 35),
              const Text(
                'Quests',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
