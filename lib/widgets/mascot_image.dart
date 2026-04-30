import 'package:flutter/material.dart';

// Displays a mascot asset from assets/images/<assetName>.png with an icon fallback.
class MascotImage extends StatelessWidget {
  final String assetName;
  final double size;

  const MascotImage({super.key, required this.assetName, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/$assetName.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.sign_language_rounded,
        size: size * 0.8,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
