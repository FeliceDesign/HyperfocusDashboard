import 'dart:math';

import 'package:flutter/material.dart';

/// Grain-Overlay bei Staub-Zustand: als Fotograf verstehst du sofort, was
/// ein unterbelichtetes, verrauschtes Bild bedeutet — da war zu wenig Licht.
class GrainOverlay extends StatelessWidget {
  const GrainOverlay({super.key, this.seed = 0, this.opacity = 0.06});

  final int seed;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GrainPainter(seed: seed, opacity: opacity),
        size: Size.infinite,
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter({required this.seed, required this.opacity});

  final int seed;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(seed);
    final area = size.width * size.height;
    final count = (area / 55).clamp(40, 900).toInt();
    for (var i = 0; i < count; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final bright = rnd.nextBool();
      final a = opacity * (0.4 + rnd.nextDouble() * 0.6);
      final paint = Paint()
        ..color = (bright ? Colors.white : Colors.black).withValues(alpha: a);
      canvas.drawRect(Rect.fromLTWH(x, y, 1.1, 1.1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.opacity != opacity;
}
