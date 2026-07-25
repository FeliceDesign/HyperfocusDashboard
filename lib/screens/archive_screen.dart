import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../services/ledger.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import 'project_detail_screen.dart';

/// Beerdigte und abgeschlossene Projekte. Sie verschwinden nicht — sie sind
/// Teil deiner Statistik und deiner Geschichte.
class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<Ledger>();
    final completed = ledger.completedProjects;
    final buried = ledger.buriedProjects;

    return Scaffold(
      appBar: AppBar(title: const Text('Archiv')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header('Abgeschlossen', completed.length, ledger),
          if (completed.isEmpty)
            _empty('Noch nichts abgeschlossen.')
          else
            ...completed.map((p) => _tile(context, p, done: true)),
          const SizedBox(height: 24),
          _header('Beerdigt', buried.length, ledger),
          if (buried.isEmpty)
            _empty('Noch nichts beerdigt. Ein bewusster Abschied ist ein Erfolg.')
          else
            ...buried.map((p) => _tile(context, p, done: false)),
        ],
      ),
    );
  }

  Widget _header(String text, int count, Ledger ledger) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('${text.toUpperCase()}  ·  $count',
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
      );

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Center(
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textFaint)),
        ),
      );

  Widget _tile(BuildContext context, Project p, {required bool done}) {
    final String subtitle;
    if (done) {
      subtitle = 'abgeschlossen · ${shortDate(p.lastCheckIn?.date ?? p.createdAt)}';
    } else if (p.burial != null) {
      // Beide Pflichtteile: Grund UND was du mitgenommen hast.
      subtitle = 'beerdigt ${shortDate(p.burial!.date)}\n'
          'Grund: ${p.burial!.reason}\n'
          'Mitgenommen: ${p.burial!.learning}';
    } else {
      subtitle = 'beerdigt';
    }
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        isThreeLine: !done && p.burial != null,
        // Monochrome Glyphen: Haken ohne Kreis / schlicht durchgestrichen.
        leading: Icon(
          done ? Icons.check : Icons.horizontal_rule,
          color: done ? AppColors.ink : AppColors.textFaint,
        ),
        title: Text(p.name, style: const TextStyle(color: AppColors.textPrimary)),
        subtitle: Text(subtitle,
            style: const TextStyle(
                color: AppColors.textFaint, fontSize: 12, height: 1.4)),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProjectDetailScreen(projectId: p.id),
        )),
      ),
    );
  }
}
