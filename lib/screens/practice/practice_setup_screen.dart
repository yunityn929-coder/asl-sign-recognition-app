import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/difficulty_constants.dart';
import '../../core/constants/route_constants.dart';
import '../../data/lesson_definitions.dart';

// S-17 — Practice Setup
class PracticeSetupScreen extends ConsumerStatefulWidget {
  final String lessonId;
  const PracticeSetupScreen({required this.lessonId, super.key});

  @override
  ConsumerState<PracticeSetupScreen> createState() => _PracticeSetupScreenState();
}

class _PracticeSetupScreenState extends ConsumerState<PracticeSetupScreen> {
  String _difficulty = 'easy';

  LessonDefinition get _def => kLessons.firstWhere(
        (l) => l.id == widget.lessonId,
        orElse: () => const LessonDefinition(id: '', section: 0, title: '', signs: []),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _LessonInfoCard(title: _def.title, signCount: _def.signs.length),
                  const SizedBox(height: 24),
                  _DifficultyCard(
                    label: 'Easy',
                    subtitle: '${kDifficultySeconds['easy']}s per sign',
                    icon: Icons.directions_walk,
                    selected: _difficulty == 'easy',
                    onTap: () => setState(() => _difficulty = 'easy'),
                  ),
                  const SizedBox(height: 12),
                  _DifficultyCard(
                    label: 'Medium',
                    subtitle: '${kDifficultySeconds['medium']}s per sign',
                    icon: Icons.directions_run,
                    selected: _difficulty == 'medium',
                    onTap: () => setState(() => _difficulty = 'medium'),
                  ),
                  const SizedBox(height: 12),
                  _DifficultyCard(
                    label: 'Hard',
                    subtitle: '${kDifficultySeconds['hard']}s per sign',
                    icon: Icons.bolt,
                    selected: _difficulty == 'hard',
                    onTap: () => setState(() => _difficulty = 'hard'),
                  ),
                  const SizedBox(height: 24),
                  _buildStartButton(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
          const Expanded(
            child: Text(
              'Choose Difficulty',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => context.push(
          kRoutePracticeSession.replaceFirst(':lessonId', widget.lessonId),
          extra: _difficulty,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text('Start Practice', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
    );
  }
}

class _LessonInfoCard extends StatelessWidget {
  final String title;
  final int signCount;
  const _LessonInfoCard({required this.title, required this.signCount});

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
                  fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('$signCount signs',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.primarySoft,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle, color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}
