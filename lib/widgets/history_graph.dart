import 'package:flutter/material.dart';

import '../models/check_in.dart';
import '../theme/app_theme.dart';

/// Verlaufsgraph: % über Zeit. Sofort erkennbar sind die Plateaus — die
/// flachen Strecken, wo nichts passiert ist. Ehrlicher als jede Selbsteinschätzung.
class HistoryGraph extends StatelessWidget {
  const HistoryGraph({super.key, required this.checkIns, required this.color});

  final List<CheckIn> checkIns;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      width: double.infinity,
      child: CustomPaint(
        painter: _GraphPainter(checkIns: checkIns, color: color),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({required this.checkIns, required this.color});

  final List<CheckIn> checkIns;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    // Gitterlinien bei 0 / 50 / 100 %.
    for (final v in [0.0, 0.5, 1.0]) {
      final y = size.height - v * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (checkIns.length < 2) {
      final tp = TextPainter(
        text: const TextSpan(
          text: 'Noch zu wenige Check-ins für einen Verlauf.',
          style: TextStyle(color: AppColors.textFaint, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      tp.paint(canvas, Offset(0, size.height / 2 - 8));
      return;
    }

    final n = checkIns.length;
    Offset pointAt(int i) {
      final x = (i / (n - 1)) * size.width;
      final y = size.height - (checkIns[i].feltPercent / 100) * size.height;
      return Offset(x, y);
    }

    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < n; i++) {
      final p = pointAt(i);
      path.lineTo(p.dx, p.dy);
    }

    // Fläche unter der Linie.
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..color = color.withValues(alpha: 0.12),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    for (var i = 0; i < n; i++) {
      final p = pointAt(i);
      canvas.drawCircle(p, 2.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) => true;
}
