import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ledger.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';

/// WIP-Limit einstellen. Änderung greift erst mit einer Woche Verzögerung —
/// kein Impuls-Upgrade um Mitternacht.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<Ledger>();
    final effectiveLimit = ledger.pendingWipLimit ?? ledger.wipLimit;

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Text('WIP-LIMIT',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${ledger.wipLimit}',
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 72,
                              fontWeight: FontWeight.w800)),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16, left: 8),
                        child: Text('aktiv erlaubt',
                            style: TextStyle(color: AppColors.textFaint)),
                      ),
                    ],
                  ),
                  Center(
                    child: Text('gerade aktiv: ${ledger.activeCount}',
                        style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    children: [1, 2, 3, 4, 5, 6].map((n) {
                      final selected = effectiveLimit == n;
                      return ChoiceChip(
                        label: Text('$n'),
                        selected: selected,
                        onSelected: (_) => ledger.requestWipLimitChange(n),
                        showCheckmark: false,
                        backgroundColor: AppColors.surface,
                        selectedColor: AppColors.interactive.withValues(alpha: 0.22),
                        side: BorderSide(
                            color: selected
                                ? AppColors.interactive
                                : AppColors.border),
                        labelStyle: TextStyle(
                            color: selected
                                ? AppColors.interactive
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w700),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  // Konsequenz-Zeile.
                  Text(
                    'Bei ${ledger.wipLimit} aktiven Projekten musst du eines '
                    'abschließen, pausieren oder beerdigen, bevor ein neues '
                    'dazukommt.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textFaint, fontSize: 13, height: 1.4),
                  ),
                  if (ledger.pendingWipLimit != null &&
                      ledger.pendingWipLimitEffectiveAt != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.deathZone.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.deathZone.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'Neues Limit ${ledger.pendingWipLimit} greift am '
                        '${shortDate(ledger.pendingWipLimitEffectiveAt!)}. Bis '
                        'dahin gilt ${ledger.wipLimit}.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.deathZone, fontSize: 13),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text('DATEN',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _confirmDemo(context, ledger),
                    icon: const Icon(Icons.science_outlined, size: 18),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.interactive,
                      side: const BorderSide(color: AppColors.interactive),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    label: const Text('Demo-Daten laden'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: ledger.hasProjects
                        ? () => _confirmClear(context, ledger)
                        : null,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(
                          color: AppColors.danger.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    label: const Text('Alle Daten löschen'),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Der Demo-Datensatz zeigt alle Verfallsstufen nebeneinander.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textFaint, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDemo(BuildContext context, Ledger ledger) async {
    final ok = await _confirm(
      context,
      'Demo-Daten laden?',
      'Ersetzt alle vorhandenen Projekte durch einen Beispiel-Datensatz, der '
          'jeden Zustand sichtbar macht — Todeszone, Verfall, verhungert, '
          'pausiert, abgeschlossen, beerdigt.',
      'Laden',
      AppColors.interactive,
    );
    if (ok) {
      ledger.loadDemoData();
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _confirmClear(BuildContext context, Ledger ledger) async {
    final ok = await _confirm(
      context,
      'Alle Daten löschen?',
      'Entfernt alle Projekte, Check-ins und Deltas endgültig. Die App wird '
          'wieder zum leeren Beichtstuhl.',
      'Löschen',
      AppColors.danger,
    );
    if (ok) {
      ledger.clearAll();
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<bool> _confirm(BuildContext context, String title, String body,
      String action, Color color) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: Text(body,
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: color),
            child: Text(action),
          ),
        ],
      ),
    );
    return r ?? false;
  }
}
