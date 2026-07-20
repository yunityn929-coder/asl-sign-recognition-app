import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/lesson_definitions.dart';
import '../../../models/lesson_model.dart';
import 'lesson_node.dart';
import 'unit_banner.dart';

const double _nodeSpacing    = 120.0;
const double _nodeRadius     = 22.0;
const double _sectionGap     = 60.0;
const double _contentTopPad  = 50.0;

class PathBody extends StatefulWidget {
  final List<LessonModel> lessons;
  final ScrollController scrollController;
  final void Function(String lessonId) onLessonTap;
  final void Function(List<double> unitTopYs)? onUnitPositionsComputed;
  final ValueNotifier<int> activeUnitNotifier;

  const PathBody({
    super.key,
    required this.lessons,
    required this.scrollController,
    required this.onLessonTap,
    required this.activeUnitNotifier,
    this.onUnitPositionsComputed,
  });

  @override
  State<PathBody> createState() => _PathBodyState();
}

class _PathBodyState extends State<PathBody> {
  int _activeUnitIdx = 0;

  @override
  void initState() {
    super.initState();
    _activeUnitIdx = widget.activeUnitNotifier.value;
    widget.activeUnitNotifier.addListener(_onActiveUnitChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportUnitPositions();
      _scrollToActive();
    });
  }

  @override
  void dispose() {
    widget.activeUnitNotifier.removeListener(_onActiveUnitChanged);
    super.dispose();
  }

  void _onActiveUnitChanged() {
    final next = widget.activeUnitNotifier.value;
    if (mounted && next != _activeUnitIdx) setState(() => _activeUnitIdx = next);
  }

  void _reportUnitPositions() {
    if (!mounted || widget.onUnitPositionsComputed == null) return;
    final ys = <double>[];
    double y = _contentTopPad;
    for (final s in kSections) {
      ys.add(y);
      final count = kLessons.where((l) => l.section == s.number).length;
      y += kSectionLabelHeight + kSectionLabelMarginB + count * _nodeSpacing + _sectionGap;
    }
    widget.onUnitPositionsComputed!(ys);
  }

  void _scrollToActive() {
    final ctrl = widget.scrollController;
    if (!ctrl.hasClients) return;
    final screenH = MediaQuery.of(context).size.height;
    double y = _contentTopPad;
    for (final section in kSections) {
      y += kSectionLabelHeight + kSectionLabelMarginB;
      final defs = kLessons.where((l) => l.section == section.number).toList();
      for (int i = 0; i < defs.length; i++) {
        final model = _modelFor(defs[i].id, section.number);
        if (model.status == 'available') {
          final nodeY = y + i * _nodeSpacing + _nodeRadius;
          final target = math.max(0.0, nodeY - screenH / 2 + 80);
          ctrl.animateTo(
            target,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
          );
          return;
        }
      }
      y += defs.length * _nodeSpacing + _sectionGap;
    }
  }

  LessonModel _modelFor(String id, int sectionNumber) {
    return widget.lessons.firstWhere(
      (l) => l.lessonId == id,
      orElse: () => LessonModel(
        lessonId: id,
        sectionNumber: sectionNumber,
        status: 'locked',
        practiceCount: 0,
        bestAccuracy: 0,
        totalXpEarned: 0,
      ),
    );
  }

  double _xForIndex(int i, double width) {
    final centreX = width * 0.50 - 50;
    final rightX  = width * 0.72 - 50;
    final leftX   = width * 0.18;
    switch (i % 5) {
      case 0: return centreX;
      case 1: return rightX;
      case 2: return centreX;
      case 3: return leftX;
      case 4: return centreX;
      default: return centreX;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final List<_NodeData> allNodes  = [];
    double currentY = _contentTopPad;

    for (final section in kSections) {
      currentY += kSectionLabelHeight + kSectionLabelMarginB;
      final defs = kLessons.where((l) => l.section == section.number).toList();

      for (int i = 0; i < defs.length; i++) {
        final cx = _xForIndex(i, width) + 50;
        final cy = currentY + i * _nodeSpacing + _nodeRadius;
        final model = _modelFor(defs[i].id, section.number);
        debugPrint('[LESSON DIAG] id=${model.lessonId} status=${model.status}');
        allNodes.add(_NodeData(
          def: defs[i],
          model: model,
          centre: Offset(cx, cy),
        ));
      }
      currentY += defs.length * _nodeSpacing + _sectionGap;
    }

    final totalH = currentY + 40.0;

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: 300),
      child: Container(
        width: width,
        height: totalH,
        child: Stack(
          children: _buildSectionWidgets(allNodes),
        ),
      ),
    );
  }

  List<Widget> _buildSectionWidgets(List<_NodeData> allNodes) {
    final widgets   = <Widget>[];
    double currentY = _contentTopPad;
    int nodeOffset  = 0;

    for (int sectionIdx = 0; sectionIdx < kSections.length; sectionIdx++) {
      final section = kSections[sectionIdx];
      if (sectionIdx != _activeUnitIdx) {
        widgets.add(Positioned(
          top: currentY - (_sectionGap / 2),
          left: 0,
          right: 0,
          child: SectionDivider(section: section),
        ));
      }
      currentY += kSectionLabelHeight + kSectionLabelMarginB;

      final defs = kLessons.where((l) => l.section == section.number).toList();

      for (int i = 0; i < defs.length; i++) {
        final node = allNodes[nodeOffset + i];
        final cx   = node.centre.dx;
        final cy   = currentY + i * _nodeSpacing;

        widgets.add(Positioned(
          left: cx - 65,
          top:  cy,
          child: LessonNode(
            definition: node.def,
            lesson: node.model,
            index: nodeOffset + i,
            onTap: node.model.status == 'locked'
                ? null
                : () => widget.onLessonTap(node.def.id),
          ),
        ));
      }

      currentY  += defs.length * _nodeSpacing + _sectionGap;
      nodeOffset += defs.length;
    }

    return widgets;
  }
}

class _NodeData {
  final LessonDefinition def;
  final LessonModel model;
  final Offset centre;
  const _NodeData({required this.def, required this.model, required this.centre});
}
