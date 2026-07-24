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

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('WIP-LIMIT',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          const Text(
            'Der schmerzhafteste und nützlichste Mechanismus der App. Maximal so '
            'viele aktive Projekte. Änderungen greifen erst nach einer Woche.',
            style: TextStyle(color: AppColors.textFaint, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${ledger.wipLimit}',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 64,
                      fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('aktuell',
                    style: TextStyle(color: AppColors.textFaint)),
              ),
            ],
          ),
          Center(
            child: Text('aktiv gerade: ${ledger.activeCount}',
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            children: [1, 2, 3, 4, 5, 6].map((n) {
              final selected = (ledger.pendingWipLimit ?? ledger.wipLimit) == n;
              return ChoiceChip(
                label: Text('$n'),
                selected: selected,
                onSelected: (_) => ledger.requestWipLimitChange(n),
                showCheckmark: false,
                backgroundColor: AppColors.surface,
                selectedColor: AppColors.deathZone.withValues(alpha: 0.25),
                side: BorderSide(
                    color: selected ? AppColors.deathZone : AppColors.border),
                labelStyle: TextStyle(
                    color:
                        selected ? AppColors.deathZone : AppColors.textSecondary,
                    fontWeight: FontWeight.w700),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          if (ledger.pendingWipLimit != null &&
              ledger.pendingWipLimitEffectiveAt != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.deathZone.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.deathZone.withValues(alpha: 0.4)),
              ),
              child: Text(
                'Neues Limit ${ledger.pendingWipLimit} greift am '
                '${shortDate(ledger.pendingWipLimitEffectiveAt!)}. Bis dahin '
                'gilt ${ledger.wipLimit}.',
                style: const TextStyle(color: AppColors.deathZone, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
