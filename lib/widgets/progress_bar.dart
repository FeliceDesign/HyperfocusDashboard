import 'package:flutter/material.dart';

import '../models/staleness.dart';
import '../theme/app_theme.dart';

/// Ein harter Balken — keine Animation. Werte ändern sich hart.
/// Bei "rissig" bekommt der Balken eine sichtbare Bruchkante.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.percent,
    required this.color,
    required this.staleness,
    this.height = 10,
    this.ghostPercent,
  });

  final int percent;
  final Color color;
  final Staleness staleness;
  final double height;

  /// Optionaler Geisterwert (alter Stand) als dünne Linie.
  final int? ghostPercent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final fill = (percent.clamp(0, 100) / 100) * w;
        final crackX = staleness.hasCrack ? fill * 0.62 : null;
        return SizedBox(
          height: height,
          width: w,
          child: Stack(
            children: [
              // Track
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Fill
              Container(
                width: fill,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Bruchkante bei rissig/staub
              if (crackX != null)
                Positioned(
                  left: crackX,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: AppColors.background),
                ),
              // Geisterlinie
              if (ghostPercent != null)
                Positioned(
                  left: (ghostPercent!.clamp(0, 100) / 100) * w - 1,
                  top: -2,
                  bottom: -2,
                  child: Container(
                    width: 2,
                    color: AppColors.textFaint.withValues(alpha: 0.9),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
