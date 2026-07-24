import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/project.dart';
import '../models/staleness.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import 'grain_overlay.dart';
import 'progress_bar.dart';

/// Die Projekt-Karte mit vier Informationsebenen:
/// Balken + %, Momentum-Pfeil, Top-Deltas als Klartext, Tage seit Check-in.
class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.onTap,
    this.onLongPress,
  });

  final Project project;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final staleness = project.staleness;
    final isPaused = project.status == ProjectStatus.pausiert;
    final effStale = isPaused ? Staleness.frisch : staleness;
    final hue = stalenessColor(project.category.hue, effStale);
    final dim = isPaused ? 0.4 : effStale.dim;

    final openDeltas = project.openDeltas;
    final topDeltas = openDeltas.take(2).map((d) => d.text).join(', ');
    final extra = openDeltas.length - 2;

    final textColor = Color.lerp(
      AppColors.textPrimary,
      AppColors.background,
      dim,
    )!;
    final metaColor = Color.lerp(
      AppColors.textSecondary,
      AppColors.background,
      dim * 0.7,
    )!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            children: [
              // Die Karte selbst bestimmt die Höhe (intrinsisch über den
              // Inhalt) — kein CrossAxisAlignment.stretch, das in einer
              // ListView mit unbegrenzter Höhe zu Null-Höhe kollabieren würde.
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                  child: _content(context, textColor, metaColor, hue, effStale,
                      topDeltas, extra, isPaused),
                ),
              ),
              // Todeszone-Markierung: dünne Linie am linken Kartenrand.
              if (project.inDeathZone)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 3,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.deathZone,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        bottomLeft: Radius.circular(10),
                      ),
                    ),
                  ),
                ),
              if (effStale.hasGrain)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: GrainOverlay(seed: project.id.hashCode),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    Color textColor,
    Color metaColor,
    Color hue,
    Staleness staleness,
    String topDeltas,
    int extra,
    bool isPaused,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titelzeile
        Row(
          children: [
            Expanded(
              child: Text(
                project.name.toUpperCase(),
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              project.category.label,
              style: TextStyle(color: hue, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Balken + % + Momentum
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: ProgressBar(
                percent: project.feltPercent,
                color: hue,
                staleness: staleness,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${project.feltPercent}%',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            // Momentum-Pfeil nur ab drei echten Check-ins.
            if (project.momentum != null) ...[
              const SizedBox(width: 6),
              Text(
                project.momentum!.arrow,
                style: TextStyle(
                  color: project.momentum == Momentum.down
                      ? AppColors.danger
                      : metaColor,
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // Top-Deltas als Klartext
        if (isPaused)
          Text(
            'pausiert${project.resumeDate != null ? ' · wieder ab ${shortDate(project.resumeDate!)}' : ''}',
            style: TextStyle(color: metaColor, fontSize: 13, fontStyle: FontStyle.italic),
          )
        else if (topDeltas.isNotEmpty)
          RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Fehlt: ',
                  style: TextStyle(color: metaColor, fontSize: 13),
                ),
                TextSpan(
                  text: topDeltas,
                  style: TextStyle(color: textColor, fontSize: 13),
                ),
                if (extra > 0)
                  TextSpan(
                    text: '  +$extra',
                    style: TextStyle(color: metaColor, fontSize: 13),
                  ),
              ],
            ),
          )
        else
          Text(
            'Keine offenen Deltas.',
            style: TextStyle(color: metaColor, fontSize: 13),
          ),
        const SizedBox(height: 6),
        // Tage seit Check-in — der Vorwurf
        Row(
          children: [
            Text(
              'letzter Check-in: ${agoLabel(project.daysSinceCheckIn)}',
              style: TextStyle(color: metaColor, fontSize: 12),
            ),
            const Spacer(),
            if (project.status == ProjectStatus.verhungert)
              _tag('VERHUNGERT', AppColors.danger)
            else if (project.inDeathZone)
              _tag('TODESZONE', AppColors.deathZone)
            else if (!isPaused && staleness != Staleness.frisch)
              _tag(staleness.label.toUpperCase(), metaColor),
          ],
        ),
      ],
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      );
}
