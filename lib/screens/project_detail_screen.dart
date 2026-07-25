import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/project.dart';
import '../models/staleness.dart';
import '../services/ledger.dart';
import '../theme/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/glyphs.dart';
import '../widgets/history_graph.dart';
import '../widgets/progress_bar.dart';
import 'burial_screen.dart';
import 'check_in_screen.dart';

class ProjectDetailScreen extends StatelessWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<Ledger>();
    final project = ledger.byId(projectId);
    if (project == null) {
      return const Scaffold(body: Center(child: Text('Projekt weg.')));
    }
    // Kategoriefarbe nur für Balken und Graph — entsättigt durch Staleness.
    final hue = stalenessColor(project.category.hue, project.staleness);

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => _onAction(context, ledger, project, v),
            color: AppColors.surfaceRaised,
            itemBuilder: (context) => [
              if (project.status == ProjectStatus.aktiv ||
                  project.status == ProjectStatus.verhungert) ...[
                const PopupMenuItem(value: 'complete', child: Text('Abschließen')),
                const PopupMenuItem(value: 'pause', child: Text('Pausieren')),
              ],
              if (project.status == ProjectStatus.pausiert)
                const PopupMenuItem(value: 'resume', child: Text('Wieder aufnehmen')),
              if (project.status != ProjectStatus.beerdigt &&
                  project.status != ProjectStatus.abgeschlossen)
                const PopupMenuItem(value: 'bury', child: Text('Beerdigen')),
            ],
          ),
        ],
      ),
      floatingActionButton: (project.status == ProjectStatus.aktiv ||
              project.status == ProjectStatus.verhungert)
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.ink,
              foregroundColor: AppColors.background,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CheckInScreen(projectId: project.id),
              )),
              icon: const Icon(Icons.bolt),
              label: const Text('Check-in',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _statusLine(project),
          const SizedBox(height: 16),
          // Definition of Done — der Nordstern, immer sichtbar.
          _dodCard(context, ledger, project),
          const SizedBox(height: 20),
          // Aktueller Stand
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${project.feltPercent}%',
                  style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      fontFeatures: kTabular)),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    if (project.momentum != null) ...[
                      Icon(momentumIcon(project.momentum!),
                          size: 16, color: momentumColor(project.momentum!)),
                      const SizedBox(width: 6),
                    ],
                    Text(project.category.label,
                        style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ProgressBar(
            percent: project.feltPercent,
            color: hue,
            staleness: project.staleness,
            height: 12,
          ),
          const SizedBox(height: 24),
          _sectionTitle('Verlauf'),
          const SizedBox(height: 8),
          HistoryGraph(checkIns: project.checkInsChrono, color: hue),
          const SizedBox(height: 24),
          _sectionTitle('Deltas'),
          const SizedBox(height: 8),
          _deltaHistory(project),
          const SizedBox(height: 24),
          _sectionTitle('Check-in-Timeline'),
          const SizedBox(height: 8),
          _timeline(project),
          if (project.status == ProjectStatus.beerdigt && project.burial != null) ...[
            const SizedBox(height: 24),
            _burialCard(project),
          ],
        ],
      ),
    );
  }

  Widget _statusLine(Project project) {
    Color color;
    String text;
    switch (project.status) {
      case ProjectStatus.verhungert:
        color = AppColors.danger;
        text = 'VERHUNGERT · ${agoLabel(project.daysSinceMeaningfulChange)} ohne Bewegung';
        break;
      case ProjectStatus.pausiert:
        color = AppColors.textSecondary;
        text = 'PAUSIERT${project.pauseReason != null ? ' · ${project.pauseReason}' : ''}';
        break;
      case ProjectStatus.abgeschlossen:
        color = AppColors.ink;
        text = 'ABGESCHLOSSEN';
        break;
      case ProjectStatus.beerdigt:
        color = AppColors.textFaint;
        text = 'BEERDIGT';
        break;
      case ProjectStatus.aktiv:
        final s = project.staleness;
        color = project.inDeathZone ? AppColors.deathZone : AppColors.textSecondary;
        text = project.inDeathZone
            ? 'TODESZONE · flach seit ${project.flatStreak} Check-ins'
            : '${s.label.toUpperCase()} · letzte Bewegung ${agoLabel(project.daysSinceMeaningfulChange)}';
        break;
    }
    return Text(text,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8));
  }

  Widget _dodCard(BuildContext context, Ledger ledger, Project project) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: const Border(left: BorderSide(color: AppColors.line, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('DEFINITION OF DONE',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
              const Spacer(),
              InkWell(
                onTap: () => _editDod(context, ledger, project),
                child: const Icon(Icons.edit, size: 16, color: AppColors.textFaint),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(project.definitionOfDone,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 16, height: 1.35)),
        ],
      ),
    );
  }

  Widget _deltaHistory(Project project) {
    // Offene Deltas nach Alter absteigend — was am längsten offen ist, oben.
    final open = project.openDeltas
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final resolved = project.resolvedDeltas
      ..sort((a, b) => (b.resolvedAt ?? b.createdAt).compareTo(a.resolvedAt ?? a.createdAt));
    if (project.deltas.isEmpty) {
      return const Text('Noch keine Deltas benannt.',
          style: TextStyle(color: AppColors.textFaint));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...open.map((d) {
          final stuck = project.isDeltaStuck(d);
          return _deltaRow(
            text: d.text,
            trailing: '${d.ageInDays} Tage offen',
            open: true,
            stuck: stuck,
          );
        }),
        ...resolved.map((d) => _deltaRow(
              text: d.text,
              trailing: 'erledigt ${shortDate(d.resolvedAt!)}',
              open: false,
              stuck: false,
            )),
      ],
    );
  }

  Widget _deltaRow({
    required String text,
    required String trailing,
    required bool open,
    required bool stuck,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            open ? Icons.radio_button_unchecked : Icons.check_circle,
            size: 16,
            color: open
                ? (stuck ? AppColors.danger : AppColors.textSecondary)
                : AppColors.textFaint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text,
                    style: TextStyle(
                      color: open ? AppColors.textPrimary : AppColors.textFaint,
                      decoration: open ? null : TextDecoration.lineThrough,
                      decorationColor: AppColors.textFaint,
                    )),
                Text(
                  stuck ? '$trailing  ·  steht zu lange' : trailing,
                  style: TextStyle(
                    color: stuck ? AppColors.danger : AppColors.textFaint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeline(Project project) {
    final chrono = project.checkInsChrono.reversed.toList();
    if (chrono.isEmpty) {
      return const Text('Noch kein Check-in.',
          style: TextStyle(color: AppColors.textFaint));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: chrono.map((c) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 44,
                child: Text('${c.feltPercent}%',
                    style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                        fontFeatures: kTabular)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shortDate(c.date),
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    if (c.note != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(c.note!,
                            style: const TextStyle(
                                color: AppColors.textFaint, fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _burialCard(Project project) {
    final b = project.burial!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BEERDIGT · ${shortDate(b.date)}',
              style: const TextStyle(
                  color: AppColors.textFaint,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(height: 10),
          Text('Grund: ${b.reason}',
              style: const TextStyle(color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text('Mitgenommen: ${b.learning}',
              style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      );

  // --- Aktionen ------------------------------------------------------------

  Future<void> _onAction(
      BuildContext context, Ledger ledger, Project project, String action) async {
    switch (action) {
      case 'complete':
        final ok = await _confirm(context, 'Abschließen?',
            'Setzt das Projekt auf 100% und schließt es ab. Ein Abschluss ist ein Erfolg.');
        if (ok) ledger.completeProject(project.id);
        break;
      case 'pause':
        await _pauseDialog(context, ledger, project);
        break;
      case 'resume':
        ledger.resumeProject(project.id);
        break;
      case 'bury':
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BurialScreen(project: project),
        ));
        break;
    }
  }

  Future<void> _editDod(BuildContext context, Ledger ledger, Project project) async {
    final ctrl = TextEditingController(text: project.definitionOfDone);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Definition of Done'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Speichern')),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      ledger.updateDefinitionOfDone(project.id, result);
    }
  }

  Future<void> _pauseDialog(
      BuildContext context, Ledger ledger, Project project) async {
    final reason = TextEditingController();
    DateTime? resume;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Bewusst pausieren'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pausiert ist eine legitime, respektierte Entscheidung. Decay '
                'stoppt, es zählt nicht mehr gegen dein WIP-Limit. Ein Grund muss sein.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reason,
                decoration: const InputDecoration(hintText: 'Warum pausiert?'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      resume == null
                          ? 'Wiederaufnahme: offen'
                          : 'Wieder ab: ${shortDate(resume!)}',
                      style: const TextStyle(color: AppColors.textFaint, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: DateTime.now().add(const Duration(days: 14)),
                      );
                      if (picked != null) setState(() => resume = picked);
                    },
                    child: const Text('Datum'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Abbrechen')),
            FilledButton(
              onPressed: reason.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Pausieren'),
            ),
          ],
        ),
      ),
    );
    if (result == true) {
      ledger.pauseProject(project.id, reason: reason.text, resumeDate: resume);
    }
  }

  Future<bool> _confirm(BuildContext context, String title, String body) async {
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
              child: const Text('Ja')),
        ],
      ),
    );
    return r ?? false;
  }
}
