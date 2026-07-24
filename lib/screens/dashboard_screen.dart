import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../services/ledger.dart';
import '../theme/app_theme.dart';
import '../widgets/project_card.dart';
import 'archive_screen.dart';
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
                      padding: const EdgeInsets.only(bottom: 96, top: 4),
                      itemCount: projects.length,
                      itemBuilder: (context, i) {
                        final p = projects[i];
                        return ProjectCard(
                          project: p,
                          onTap: () => _openProject(p),
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
              const Text('FOCUS LEDGER',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: full
                      ? AppColors.danger.withValues(alpha: 0.15)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: full ? AppColors.danger : AppColors.border),
                ),
                child: Text(
                  'aktiv: ${ledger.activeCount} / ${ledger.wipLimit}',
                  style: TextStyle(
                      color: full ? AppColors.danger : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
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
                  style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text('Letzter Abschluss: noch keiner',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
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
              const Text('Leere Warteschlange.',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                'Diese App optimiert nicht fürs Anfangen, sondern fürs '
                'Abschließen. Leg genau das an, was du wirklich fertig machen '
                'willst — und definiere, wann es fertig ist.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textFaint, fontSize: 14, height: 1.4),
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

  Future<void> _newProject() async {
    final ledger = context.read<Ledger>();
    if (ledger.wipFull) {
      // Kein "Trotzdem"-Button. Erst Platz schaffen.
      final freed = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => const WipBlockScreen(),
      ));
      if (freed != true || ledger.wipFull) return;
    }
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const NewProjectScreen(),
    ));
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
