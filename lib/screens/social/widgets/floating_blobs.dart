import 'package:flutter/material.dart';

class FloatingBlobs extends StatefulWidget {
  const FloatingBlobs({super.key});

  @override
  State<FloatingBlobs> createState() => _FloatingBlobsState();
}

class _FloatingBlobsState extends State<FloatingBlobs>
    with TickerProviderStateMixin {
  static const List<_BlobSpec> _specs = [
    _BlobSpec(color: Color(0xFFB8F0E0), size: 80, dx: 0.08, dy: 0.10),
    _BlobSpec(color: Color(0xFFFFD4E8), size: 60, dx: 0.64, dy: 0.04),
    _BlobSpec(color: Color(0xFFFFE8A3), size: 70, dx: 0.20, dy: 0.54),
    _BlobSpec(color: Color(0xFFB8DCFF), size: 50, dx: 0.58, dy: 0.46),
  ];
  static const List<int> _durations = [2200, 2700, 3100, 2500];

  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = [
      for (final d in _durations)
        AnimationController(
          vsync: this,
          duration: Duration(milliseconds: d),
        )..repeat(reverse: true),
    ];
    _anims = [
      for (final c in _controllers)
        Tween<double>(begin: -8, end: 8).animate(
          CurvedAnimation(parent: c, curve: Curves.easeInOut),
        ),
    ];
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) => SizedBox.expand(
        child: Stack(
          children: [
            for (var i = 0; i < _specs.length; i++)
              AnimatedBuilder(
                animation: _anims[i],
                builder: (_, child) => Positioned(
                  left: constraints.maxWidth * _specs[i].dx,
                  top: constraints.maxHeight * _specs[i].dy + _anims[i].value,
                  child: child!,
                ),
                child: Container(
                  width: _specs[i].size,
                  height: _specs[i].size,
                  decoration: BoxDecoration(
                    color: _specs[i].color,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: _specs[i].color.withOpacity(0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BlobSpec {
  const _BlobSpec({
    required this.color,
    required this.size,
    required this.dx,
    required this.dy,
  });
  final Color color;
  final double size;
  final double dx; // fraction of container width
  final double dy; // fraction of container height
}
