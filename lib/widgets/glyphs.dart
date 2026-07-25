import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../theme/app_theme.dart';

/// Monochrome Vektor-Glyphen statt Emojis — alle in currentColor.
IconData momentumIcon(Momentum m) {
  switch (m) {
    case Momentum.up:
      return Icons.north_east; // Pfeil 45° aufwärts
    case Momentum.flat:
      return Icons.trending_flat; // horizontaler Strich mit Spitze
    case Momentum.down:
      return Icons.south_east; // Pfeil 45° abwärts
  }
}

Color momentumColor(Momentum m) {
  switch (m) {
    case Momentum.up:
      return AppColors.ink;
    case Momentum.flat:
      return AppColors.inkMuted;
    case Momentum.down:
      return AppColors.warn;
  }
}

/// Die Wortmarke: Versalien, Letter-Spacing 0.08em, Weight 600.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.fontSize = 20, this.color});

  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      'NON FINITO',
      style: TextStyle(
        color: color ?? AppColors.ink,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: fontSize * 0.08, // 0.08em
      ),
    );
  }
}

/// Das Icon als kleinste Ausgabe desselben Systems: ein Ring, der bei 78 %
/// endet, davor drei Brüche, deren Abstand sich zum Abbruch hin verkürzt.
/// Variante C mit `stroke-linecap="butt"`.
class NonFinitoMark extends StatelessWidget {
  const NonFinitoMark({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MarkPainter(color ?? AppColors.ink),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color);

  final Color color;

  // Dash-Segmente (startWinkel, Bogen) in Grad, ab -90° (oben), im
  // Uhrzeigersinn. Entspricht stroke-dasharray "110 5 36 5 17 5 8.2 52.56"
  // bei Umfang 238.76 (r = 38). Butt-Enden, keine runden Kappen.
  static const List<List<double>> _segments = [
    [-90.0, 165.87],
    [83.41, 54.28],
    [145.23, 25.63],
    [178.40, 12.36],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.09;
    final r = size.width * 0.38;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: r);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    for (final seg in _segments) {
      canvas.drawArc(
        rect,
        seg[0] * math.pi / 180,
        seg[1] * math.pi / 180,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
