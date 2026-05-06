import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/lesson_definitions.dart';

class SectionCard extends StatelessWidget {
  final SectionDefinition section;
  final int completedCount;
  final int total;
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  const SectionCard({
    super.key,
    required this.section,
    required this.completedCount,
    required this.total,
    required this.isExpanded,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isFullyCompleted = total > 0 && completedCount == total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                _SectionBadge(
                  number: section.number,
                  isFullyCompleted: isFullyCompleted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$completedCount / $total lessons',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...children,
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SectionBadge extends StatelessWidget {
  final int number;
  final bool isFullyCompleted;
  const _SectionBadge({required this.number, required this.isFullyCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isFullyCompleted
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isFullyCompleted
            ? const Icon(Icons.check_rounded, color: AppColors.success, size: 20)
            : Text(
                '$number',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}
