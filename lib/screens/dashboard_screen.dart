import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/project.dart';
import '../services/ledger.dart';
import '../theme/app_theme.dart';
import '../widgets/glyphs.dart';
import '../widgets/project_card.dart';
import 'archive_screen.dart';
import 'burial_screen.dart';
import 'check_in_screen.dart';
import 'new_project_screen.dart';
import 'project_detail_screen.dart';
import 'settings_screen.dart';
import 'weekly_report_screen.dart';
import 'wip_block_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _askedThisSession = false;

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<Ledger>();

    if (!ledger.loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Pausiert-oder-verhungert-Frage genau einmal pro App-Start.
    if (!_askedThisSession) {
      _askedThisSession = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _askStaleDecisions());
    }

    final projects = ledger.dashboardProjects;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(context, ledger),
            Expanded(
              child: projects.isEmpty
                  ? _empty(context)
                  : ListView.builder(
                      // Genug Luft unten, damit der FAB keine Karte überlappt.
                      padding: const EdgeInsets.only(bottom: 112, top: 4),
                      itemCount: projects.length,
                      itemBuilder: (context, i) {
                        final p = projects[i];
                        return ProjectCard(
                          project: p,
                          onTap: () => _openProject(p),
                          onLongPress: () => _cardMenu(p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.textPrimary,
        foregroundColor: AppColors.background,
        onPressed: _newProject,
        icon: const Icon(Icons.add),
        label: const Text('Projekt', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _header(BuildContext context, Ledger ledger) {
    final full = ledger.wipFull;
    final lastCompletion = ledger.lastCompletionDate;
    final daysSince =
        lastCompletion == null ? null : DateTime.now().difference(lastCompletion).inDays;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const NonFinitoMark(size: 22),
              const SizedBox(width: 10),
              const Wordmark(fontSize: 20),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  // WIP-Limit erreicht ist eine Warnung (warm), kein Fehler.
                  color: full
                      ? AppColors.warn.withValues(alpha: 0.15)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: full ? AppColors.warn : AppColors.border),
                ),
                child: Text(
                  'aktiv: ${ledger.activeCount} / ${ledger.wipLimit}',
                  style: TextStyle(
                      color: full ? AppColors.warn : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      fontFeatures: kTabular),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                color: AppColors.surfaceRaised,
                onSelected: _onMenu,
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'report', child: Text('Wochenbericht')),
                  PopupMenuItem(value: 'archive', child: Text('Archiv')),
                  PopupMenuItem(value: 'settings', child: Text('Einstellungen')),
                ],
              ),
            ],
          ),
          if (daysSince != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Letzter Abschluss: vor $daysSince Tagen',
                  style: const TextStyle(
                      color: AppColors.textFaint,
                      fontSize: 12,
                      fontFeatures: kTabular)),
            )
          else
            // Harter Negativfakt → --alert.
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text('Letzter Abschluss: noch keiner',
                  style: TextStyle(color: AppColors.alert, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Noch keine Projekte.',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Text(
                'Ein Projekt ist etwas, von dem du in einem Satz\n'
                'sagen kannst, wann es fertig ist.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textFaint, fontSize: 14, height: 1.5),
              ),
            ],
          ),
        ),
      );

  // --- Navigation ----------------------------------------------------------

  void _openProject(Project p) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProjectDetailScreen(projectId: p.id),
    ));
  }

  /// Long-Press → Kontextmenü: Check-in, Pausieren, Abschließen, Beerdigen.
  Future<void> _cardMenu(Project p) async {
    final ledger = context.read<Ledger>();
    final canCheckIn = p.status == ProjectStatus.aktiv ||
        p.status == ProjectStatus.verhungert;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(p.name.toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                  const Spacer(),
                  Text('${p.feltPercent}%',
                      style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                          fontFeatures: kTabular)),
                ],
              ),
            ),
            if (canCheckIn)
              _sheetItem(context, Icons.bolt, 'Check-in', 'checkin'),
            if (p.status == ProjectStatus.aktiv ||
                p.status == ProjectStatus.verhungert)
              _sheetItem(context, Icons.check, 'Abschließen', 'complete'),
            if (p.status == ProjectStatus.aktiv ||
                p.status == ProjectStatus.verhungert)
              _sheetItem(context, Icons.pause_circle_outline, 'Pausieren', 'pause'),
            if (p.status == ProjectStatus.pausiert)
              _sheetItem(context, Icons.play_circle_outline, 'Wieder aufnehmen', 'resume'),
            if (p.status != ProjectStatus.beerdigt &&
                p.status != ProjectStatus.abgeschlossen)
              _sheetItem(context, Icons.horizontal_rule, 'Beerdigen', 'bury'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'checkin':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CheckInScreen(projectId: p.id),
        ));
        break;
      case 'complete':
        ledger.completeProject(p.id);
        break;
      case 'pause':
        await _pauseSheet(ledger, p.id);
        break;
      case 'resume':
        ledger.resumeProject(p.id);
        break;
      case 'bury':
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BurialScreen(project: p),
        ));
        break;
    }
  }

  Widget _sheetItem(BuildContext ctx, IconData icon, String label, String value) =>
      ListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(label, style: const TextStyle(color: AppColors.textPrimary)),
        onTap: () => Navigator.pop(ctx, value),
      );

  Future<void> _pauseSheet(Ledger ledger, String id) async {
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

  Future<void> _newProject() async {
    final ledger = context.read<Ledger>();
    String? ideaName;
    if (ledger.wipFull) {
      // Kein "Trotzdem"-Button. Erst die Idee benennen, dann Platz schaffen —
      // damit die Abwägung beide Seiten der Waage zeigt.
      ideaName = await _askIdeaName();
      if (ideaName == null) return; // abgebrochen
      final freed = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => WipBlockScreen(newIdeaName: ideaName),
      ));
      if (freed != true || ledger.wipFull) return;
    }
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NewProjectScreen(initialName: ideaName),
    ));
  }

  Future<String?> _askIdeaName() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Neue Idee'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Wie heißt sie?'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.isNotEmpty) Navigator.pop(context, t);
            },
            child: const Text('Weiter'),
          ),
        ],
      ),
    );
  }

  void _onMenu(String value) {
    Widget screen;
    switch (value) {
      case 'report':
        screen = const WeeklyReportScreen();
        break;
      case 'archive':
        screen = const ArchiveScreen();
        break;
      case 'settings':
        screen = const SettingsScreen();
        break;
      default:
        return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  // --- Pausiert-oder-verhungert-Frage --------------------------------------

  Future<void> _askStaleDecisions() async {
    final ledger = context.read<Ledger>();
    final pending = ledger.projectsNeedingDecision;
    for (final p in pending) {
      if (!mounted) return;
      await _staleDialog(ledger, p);
    }
  }

  Future<void> _staleDialog(Ledger ledger, Project p) async {
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(p.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('liegt seit ${p.daysSinceMeaningfulChange} Tagen.',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
            const SizedBox(height: 12),
            const Text(
              'Bewusst pausiert oder entglitten? "Pausiert" ist eine '
              'Entscheidung — Decay stoppt, zählt nicht gegen WIP. '
              '"Entglitten" heißt verhungert: es zählt weiter gegen dich.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'starved'),
            child: const Text('Entglitten',
                style: TextStyle(color: AppColors.danger)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'pause'),
            child: const Text('Bewusst pausiert'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (action == 'starved') {
      ledger.markStarved(p.id);
    } else if (action == 'pause') {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Grund fürs Pausieren'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Ein Grund muss sein.'),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Pausieren'),
            ),
          ],
        ),
      );
      if (ok == true) {
        ledger.pauseProject(p.id,
            reason: ctrl.text.trim().isEmpty ? 'kein Grund angegeben' : ctrl.text);
      }
    }
  }
}
