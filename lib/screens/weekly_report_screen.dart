import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ledger.dart';
import '../theme/app_theme.dart';

/// Der Wochenbericht. Keine Grafiken-Orgie, nur Zahlen und Klartext.
/// Kein "Gut gemacht!", kein Ausgleich mit positiven Zahlen.
class WeeklyReportScreen extends StatelessWidget {
  const WeeklyReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<Ledger>();
    final r = ledger.weeklyReport();

    return Scaffold(
      appBar: AppBar(title: const Text('Wochenbericht')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
          Center(
            child: Text('WOCHE ${r.week} / ${r.year}',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
          ),
          const SizedBox(height: 24),
          _row('Netto-Fortschritt',
              '${r.netProgress >= 0 ? '+' : ''}${r.netProgress}%   ·  ${r.projectsCounted} von ${ledger.activeCount} Projekten bewegt'),
          _row('Deltas geschlossen', '${r.deltasClosed}'),
          _row('Deltas neu', '${r.deltasNew}'),
          _row('Abschlüsse', '${r.completions}'),
          _row(
            'Letzter Abschluss',
            r.daysSinceLastCompletion == null
                ? 'noch keiner'
                : 'vor ${r.daysSinceLastCompletion} Tagen',
            emphasize: true,
            // Rot erst, wenn es Rot verdient: 0–29 Tage sind ganz normal.
            valueColor: _completionColor(r.daysSinceLastCompletion),
          ),
          const SizedBox(height: 28),
          if (r.deathZone.isNotEmpty) ...[
            _sectionHeader('IN DER TODESZONE', AppColors.deathZone),
            ...r.deathZone.map((p) => _projectLine(
                p.name, '${p.feltPercent}%', 'flach seit ${p.flatStreak} Check-ins',
                AppColors.deathZone)),
            const SizedBox(height: 20),
          ],
          if (r.starved.isNotEmpty) ...[
            _sectionHeader('VERHUNGERT', AppColors.danger),
            ...r.starved.map((p) => _projectLine(p.name, '${p.feltPercent}%',
                '${p.daysSinceMeaningfulChange} Tage still', AppColors.danger)),
            const SizedBox(height: 20),
          ],
          if (r.deathZone.isEmpty && r.starved.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Keine Todeszone, nichts verhungert. Fürs Erste.',
                  style: TextStyle(color: AppColors.textFaint)),
            ),
            ],
          ),
        ),
      ),
    );
  }

  /// Schwellwerte für „Letzter Abschluss": Acht Tage sind kein Alarm.
  /// 0–29 → --ink, 30–89 → --warn, 90+ oder „noch keiner" → --alert.
  static Color _completionColor(int? days) {
    if (days == null) return AppColors.alert; // noch keiner
    if (days >= 90) return AppColors.alert;
    if (days >= 30) return AppColors.warn;
    return AppColors.ink;
  }

  Widget _row(String label, String value,
          {bool emphasize = false, Color? valueColor}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: emphasize
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: emphasize ? 15 : 14,
                      fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400)),
            ),
            Text(value,
                style: TextStyle(
                    color: valueColor ??
                        (emphasize ? AppColors.danger : AppColors.textPrimary),
                    fontSize: emphasize ? 16 : 15,
                    fontWeight: FontWeight.w700,
                    fontFeatures: kTabular)),
          ],
        ),
      );

  Widget _sectionHeader(String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1)),
      );

  Widget _projectLine(String name, String percent, String note, Color color) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 160,
              child: Text(name,
                  style: const TextStyle(color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis),
            ),
            SizedBox(
              width: 48,
              child: Text(percent,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontFeatures: kTabular)),
            ),
            Expanded(
              child: Text(note,
                  style: const TextStyle(
                      color: AppColors.textFaint, fontSize: 13)),
            ),
          ],
        ),
      );
}
