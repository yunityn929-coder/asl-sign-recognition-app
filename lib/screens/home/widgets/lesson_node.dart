import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/lesson_definitions.dart';
import '../../../models/lesson_model.dart';

class LessonNode extends StatelessWidget {
  final LessonDefinition definition;
  final LessonModel lesson;
  final VoidCallback? onTap;
  final int index;

  const LessonNode({
    super.key,
    required this.definition,
    required this.lesson,
    required this.index,
    this.onTap,
  });

  bool get _isCompleted => lesson.status == 'completed';
  bool get _isLocked    => lesson.status == 'locked';
  bool get _isActive    => !_isCompleted && !_isLocked;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isLocked ? null : onTap,
      child: SizedBox(
        width: 130,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (_isActive)
              const Positioned(
                top: -48,
                left: 10,
                child: Center(child: _ContinueTooltip()),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _NodeCoin(
                  isCompleted: _isCompleted,
                  isLocked: _isLocked,
                  index: index,
                ),
                const SizedBox(height: 6),
                Text(
                  definition.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF444444),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeCoin extends StatelessWidget {
  final bool isCompleted;
  final bool isLocked;
  final int index;

  const _NodeCoin({
    required this.isCompleted,
    required this.isLocked,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final faceColor = isLocked
        ? const Color(0xFFECECEC)
        : const Color(0xFFFFD166);

    final sideColor = isLocked
        ? const Color(0xFFCACDD6)
        : const Color(0xFFFFAB17);

    const ovalRadius = BorderRadius.all(Radius.elliptical(48, 20));

    return SizedBox(
      width: 96,
      height: 52,
      child: Stack(
        children: [
          Positioned(
            top: 6,
            left: 0,
            child: Container(
              width: 96,
              height: 44,
              decoration: BoxDecoration(
                color: sideColor,
                borderRadius: ovalRadius,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 96,
              height: 40,
              decoration: BoxDecoration(
                color: faceColor,
                borderRadius: ovalRadius,
              ),
              child: Center(
                child: _NodeIcon(
                  isCompleted: isCompleted,
                  isLocked: isLocked,
                  index: index,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeIcon extends StatelessWidget {
  final bool isCompleted;
  final bool isLocked;
  final int index;

  const _NodeIcon({
    required this.isCompleted,
    required this.isLocked,
    required this.index,
  });

  static const _lockedIcons = [
    Icons.auto_awesome,
    Icons.abc,
    Icons.refresh,
    Icons.chat_bubble_outline,
  ];

  @override
  Widget build(BuildContext context) {
    if (isCompleted) {
      return const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 26);
    }
    if (isLocked) {
      return Icon(
        _lockedIcons[index % 4],
        color: const Color(0xFF888888),
        size: 26,
      );
    }
    return const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 26);
  }
}

class _ContinueTooltip extends StatefulWidget {
  const _ContinueTooltip();

  @override
  State<_ContinueTooltip> createState() => _ContinueTooltipState();
}

class _ContinueTooltipState extends State<_ContinueTooltip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _translateY;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _translateY = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _translateY,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _translateY.value),
        child: child,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.hardShadow, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.hardShadow,
                  offset: Offset(2, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: const Text(
              'Continue',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.labelBlack,
              ),
            ),
          ),
          SizedBox(
            width: 12,
            height: 7,
            child: CustomPaint(painter: _TrianglePainter()),
          ),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fillPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = Colors.white);

    // Draw only the two angled sides — top edge merges with container border
    final borderPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(
      borderPath,
      Paint()
        ..color = AppColors.hardShadow
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => false;
}
