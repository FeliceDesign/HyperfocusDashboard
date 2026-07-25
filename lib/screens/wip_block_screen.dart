import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ledger.dart';
import '../theme/app_theme.dart';
import '../widgets/progress_bar.dart';
import 'burial_screen.dart';

/// Wenn das WIP-Limit voll ist, gibt es keinen "Trotzdem"-Button. Du musst ein
/// bestehendes Projekt abschließen, pausieren oder beerdigen.
class WipBlockScreen extends StatelessWidget {
  const WipBlockScreen({super.key, this.newIdeaName});

  /// Die blockierte neue Idee — damit die Abwägung beide Seiten der Waage zeigt.
  final String? newIdeaName;

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<Ledger>();
    final active =
        ledger.all.where((p) => p.status.countsAgainstWip).toList()
          ..sort((a, b) => b.feltPercent.compareTo(a.feltPercent));

    // Sobald wieder Platz ist, schließen wir diesen Screen automatisch.
    if (!ledger.wipFull) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop(true);
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('WIP-Limit voll')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (newIdeaName != null && newIdeaName!.trim().isNotEmpty) ...[
            const Text('NEUE IDEE',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(newIdeaName!.trim(),
                style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              // Eine Entscheidung, kein Fehler → --warn, nicht --alert.
              color: AppColors.warn.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warn.withValues(alpha: 0.4)),
            ),
            child: Text(
              'Du hast ${ledger.activeCount} von ${ledger.wipLimit} aktiven '
              'Projekten. Ist diese Idee wirklich wichtiger als eines davon? '
              'Meistens nicht. Aber du musst es aktiv entscheiden.',
              style: const TextStyle(color: AppColors.warn, fontSize: 14, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          ...active.map((p) => _card(context, ledger, p)),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Ledger ledger, project) {
    final hue = stalenessColor(project.category.hue, project.staleness);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(project.name.toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
              ),
              Text('${project.feltPercent}%',
                  style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      fontFeatures: kTabular)),
            ],
          ),
          const SizedBox(height: 10),
          ProgressBar(
              percent: project.feltPercent, color: hue, staleness: project.staleness),
          const SizedBox(height: 12),
          Row(
            children: [
              _btn('Abschließen', AppColors.ink,
                  () => ledger.completeProject(project.id)),
              const SizedBox(width: 8),
              _btn('Pausieren', AppColors.textSecondary,
                  () => _pause(context, ledger, project.id)),
              const SizedBox(width: 8),
              _btn('Beerdigen', AppColors.textSecondary, () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => BurialScreen(project: project),
                ));
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap) => Expanded(
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      );

  Future<void> _pause(BuildContext context, Ledger ledger, String id) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Bewusst pausieren'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Warum pausiert?'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Pausieren')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      ledger.pauseProject(id, reason: ctrl.text);
    }
  }
}
