import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/lesson_definitions.dart';

const List<Color> kBannerPalette = [
  Color(0xFFFFD166), // Unit 1 — gold
  Color(0xFF5BC8AC), // Unit 2 — teal
  Color(0xFF6EC6E6), // Unit 3 — sky blue
  Color(0xFFFF9D6C), // Unit 4 — soft orange
  Color(0xFFA78BFA), // Unit 5 — lavender
];

const List<Color> _kBannerShadows = [
  Color(0xFFFFA90C), // Unit 1 — dark gold
  Color(0xFF2E9478), // Unit 2 — dark teal
  Color(0xFF3A8FAD), // Unit 3 — dark sky
  Color(0xFFCC6030), // Unit 4 — dark orange
  Color(0xFF6B4FCC), // Unit 5 — dark lavender
];

// Sticky banner that updates content as the user scrolls.
class StickyUnitBanner extends StatefulWidget {
  final ValueNotifier<int> activeIndex;
  final List<SectionDefinition> sections;

  const StickyUnitBanner({
    super.key,
    required this.activeIndex,
    required this.sections,
  });

  @override
  State<StickyUnitBanner> createState() => _StickyUnitBannerState();
}

class _StickyUnitBannerState extends State<StickyUnitBanner> {
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _current = widget.activeIndex.value;
    widget.activeIndex.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.activeIndex.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final next = widget.activeIndex.value;
    if (mounted && next != _current) setState(() => _current = next);
  }

  @override
  Widget build(BuildContext context) {
    final idx = _current.clamp(0, widget.sections.length - 1);
    final bgColor     = kBannerPalette[idx % kBannerPalette.length];
    final shadowColor = _kBannerShadows[idx % _kBannerShadows.length];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              offset: const Offset(0, 4),
              blurRadius: 0,
              spreadRadius: 0,
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.12),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
              child: child,
            ),
          ),
          child: _BannerContent(
            key: ValueKey(idx),
            section: widget.sections[idx],
          ),
        ),
      ),
    );
  }
}

class _BannerContent extends StatelessWidget {
  final SectionDefinition section;
  const _BannerContent({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UNIT ${section.number}',
            style: const TextStyle(
              fontSize: 10,
              color: Color(0x88000000),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          Text(
            section.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.labelBlack,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// Thin inline divider rendered in the scroll body between unit sections.
class SectionDivider extends StatelessWidget {
  final SectionDefinition section;
  const SectionDivider({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kSectionLabelHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Expanded(
              child: Divider(
                color: Colors.black.withValues(alpha: 0.18),
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'UNIT ${section.number} · ${section.title.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.7,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: Colors.black.withValues(alpha: 0.18),
                thickness: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const double kSectionLabelHeight = 20.0;
const double kSectionLabelMarginB = 4.0;
