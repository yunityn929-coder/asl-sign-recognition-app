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
import '../../services/tts_service.dart';
import 'widgets/lesson_card.dart';
import 'widgets/quest_strip.dart';
import 'widgets/section_card.dart';

// S-13 — Home
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Set<int> _expanded = {1};
  bool _lessonsFallbackTriggered = false;

  @override
  Widget build(BuildContext context) {
    return ref.watch(authStateProvider).when(
          data: (user) {
            if (user == null) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return _HomeScaffold(
              uid: user.uid,
              expanded: _expanded,
              onToggle: (n) => setState(() =>
                  _expanded.contains(n) ? _expanded.remove(n) : _expanded.add(n)),
              fallbackTriggered: _lessonsFallbackTriggered,
              onFallbackTriggered: () => _lessonsFallbackTriggered = true,
            );
          },
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, __) => const Scaffold(
            body: Center(child: Text('Something went wrong.')),
          ),
        );
  }
}

class _HomeScaffold extends ConsumerWidget {
  final String uid;
  final Set<int> expanded;
  final void Function(int) onToggle;
  final bool fallbackTriggered;
  final VoidCallback onFallbackTriggered;

  const _HomeScaffold({
    required this.uid,
    required this.expanded,
    required this.onToggle,
    required this.fallbackTriggered,
    required this.onFallbackTriggered,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider(uid));
    final lessonsAsync = ref.watch(lessonProvider(uid));
    final user = userAsync.asData?.value;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: _buildAppBar(context, user),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const QuestStrip(),
          Expanded(
            child: lessonsAsync.when(
              data: (lessons) => _buildLessons(context, ref, lessons),
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

  PreferredSizeWidget _buildAppBar(BuildContext context, UserModel? user) {
    final xp = user?.totalXp ?? 0;
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

  Widget _buildLessons(BuildContext context, WidgetRef ref, List<LessonModel> lessons) {
    if (lessons.isEmpty && !fallbackTriggered) {
      onFallbackTriggered();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(firestoreServiceProvider).initLessons(uid, 's1l1').catchError((_) {});
      });
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: kSections.length,
      itemBuilder: (context, idx) {
        final section = kSections[idx];
        final defs = kLessons.where((l) => l.section == section.number).toList();
        final sectionLessons = lessons.where((l) => l.sectionNumber == section.number).toList();
        final completedCount = sectionLessons.where((l) => l.status == 'completed').length;
        final isExpanded = expanded.contains(section.number);

        return SectionCard(
          section: section,
          completedCount: completedCount,
          total: defs.length,
          isExpanded: isExpanded,
          onToggle: () => onToggle(section.number),
          children: defs.map((def) {
            final model = sectionLessons.firstWhere(
              (l) => l.lessonId == def.id,
              orElse: () => LessonModel(
                lessonId: def.id,
                sectionNumber: def.section,
                status: 'locked',
                practiceCount: 0,
                bestAccuracy: 0,
                totalXpEarned: 0,
              ),
            );
            return LessonCard(
              definition: def,
              lesson: model,
              onTap: model.status == 'locked'
                  ? null
                  : () {
                      ref.read(ttsServiceProvider).speak(def.title);
                      context.goNamed(
                        kRouteNameModeSelect,
                        pathParameters: {'lessonId': def.id},
                      );
                    },
            );
          }).toList(),
        );
      },
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
