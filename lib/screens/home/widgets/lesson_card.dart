import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/lesson_definitions.dart';
import '../../../models/lesson_model.dart';

class LessonCard extends StatelessWidget {
  final LessonDefinition definition;
  final LessonModel lesson;
  final VoidCallback? onTap;

  const LessonCard({
    super.key,
    required this.definition,
    required this.lesson,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = lesson.status == 'locked';
    final isCompleted = lesson.status == 'completed';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 12, bottom: 8, right: 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isLocked ? const Color(0xFFF5F5F8) : AppColors.backgroundCard,
          border: !isLocked && !isCompleted
              ? Border.all(color: AppColors.primarySoft, width: 1.5)
              : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isLocked
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            _StatusIcon(isLocked: isLocked, isCompleted: isCompleted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    definition.title,
                    style: TextStyle(
                      color: isLocked ? AppColors.textSecondary : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (definition.signs.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${definition.signs.length} signs',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            if (isCompleted)
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22)
            else if (!isLocked)
              const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary, size: 13),
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final bool isLocked;
  final bool isCompleted;
  const _StatusIcon({required this.isLocked, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isLocked
            ? const Color(0xFFE0E0E6)
            : isCompleted
                ? AppColors.success.withValues(alpha: 0.12)
                : AppColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isLocked
            ? Icons.lock_rounded
            : isCompleted
                ? Icons.check_rounded
                : Icons.menu_book_rounded,
        color: isLocked
            ? const Color(0xFF9E9EAE)
            : isCompleted
                ? AppColors.success
                : AppColors.primary,
        size: 17,
      ),
    );
  }
}
