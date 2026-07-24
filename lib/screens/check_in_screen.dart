import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/delta_item.dart';
import '../models/project.dart';
import '../services/ledger.dart';
import '../theme/app_theme.dart';
import '../widgets/progress_bar.dart';

/// Der Check-in — 30–60 Sekunden, vier Schritte. Alles andere in der App ist
/// nur Visualisierung dieses einen Flows.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key, required this.projectId});

  final String projectId;

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _controller = PageController();
  int _page = 0;

  final Set<String> _resolved = {};
  final List<TextEditingController> _newDeltas = [TextEditingController()];
  late int _percent;
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = context.read<Ledger>().byId(widget.projectId);
    _percent = p?.feltPercent ?? 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final c in _newDeltas) {
      c.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final ledger = context.read<Ledger>();
    final project = ledger.byId(widget.projectId);
    if (project == null) return;

    final oldPercent = project.feltPercent;
    final newTexts = _newDeltas
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    // Prozent gestiegen, aber nichts abgeschlossen → genau einmal nachfragen.
    if (_percent > oldPercent && _resolved.isEmpty && _note.text.trim().isEmpty) {
      final reason = await _askWhy();
      if (reason == null) return; // abgebrochen
      _note.text = reason;
    }

    ledger.checkIn(
      projectId: widget.projectId,
      resolvedDeltaIds: _resolved,
      newDeltaTexts: newTexts,
      feltPercent: _percent,
      note: _note.text,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<String?> _askWhy() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Prozent gestiegen, aber nichts abgeschlossen.'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Was ist passiert? Manchmal gibt es gute Gründe. Meistens nicht.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Eine Zeile.'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
                context, ctrl.text.trim().isEmpty ? '—' : ctrl.text.trim()),
            child: const Text('Weiter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.watch<Ledger>();
    final project = ledger.byId(widget.projectId);
    if (project == null) {
      return const Scaffold(body: Center(child: Text('Projekt weg.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Check-in · ${project.name}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_page + 1) / 3,
            backgroundColor: AppColors.surface,
            color: project.category.hue,
            minHeight: 3,
          ),
        ),
      ),
      body: PageView(
        controller: _controller,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _page = i),
        children: [
          _stepOpenDeltas(project),
          _stepNewDeltas(project),
          _stepPercent(project),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (_page > 0)
                TextButton(
                  onPressed: () => _controller.previousPage(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                  ),
                  child: const Text('Zurück'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _next,
                style: FilledButton.styleFrom(
                  backgroundColor: project.category.hue,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
                child: Text(
                  _page < 2 ? 'Weiter' : 'Check-in abschließen',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Schritt 1: offene Deltas -------------------------------------------
  Widget _stepOpenDeltas(Project project) {
    final open = project.openDeltas;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _stepHeader('1 · Deine offenen Deltas',
            'Was hast du seit dem letzten Mal wirklich abgeschlossen?'),
        const SizedBox(height: 8),
        if (open.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Keine offenen Deltas. Entweder frisch — oder du hast letztes Mal '
              'nichts benannt.',
              style: TextStyle(color: AppColors.textFaint),
            ),
          )
        else
          ...open.map((d) => _deltaToggle(d, project)),
      ],
    );
  }

  Widget _deltaToggle(DeltaItem d, Project project) {
    final checked = _resolved.contains(d.id);
    final stuck = project.isDeltaStuck(d);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() {
          if (checked) {
            _resolved.remove(d.id);
          } else {
            _resolved.add(d.id);
          }
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: checked ? project.category.hue : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                checked
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: checked ? project.category.hue : AppColors.textFaint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  d.text,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    decoration: checked ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.textFaint,
                  ),
                ),
              ),
              if (stuck)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text('steht',
                      style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Schritt 2: neue Deltas ---------------------------------------------
  Widget _stepNewDeltas(Project project) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _stepHeader('2 · Neue Deltas',
            'Was ist seit dem letzten Check-in dazugekommen? Fast immer mehr, '
                'als du erwartet hast.'),
        const SizedBox(height: 8),
        ...List.generate(_newDeltas.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newDeltas[i],
                    decoration: InputDecoration(
                      hintText: 'Konkretes Item, kein "Feinschliff"',
                      isDense: true,
                      suffixIcon: _newDeltas.length > 1
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() {
                                _newDeltas.removeAt(i).dispose();
                              }),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () =>
              setState(() => _newDeltas.add(TextEditingController())),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Noch ein Delta'),
        ),
      ],
    );
  }

  // --- Schritt 3: gefühlter Prozentsatz -----------------------------------
  Widget _stepPercent(Project project) {
    final old = project.feltPercent;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _stepHeader('3 · Gefühlter Prozentsatz',
            'Der alte Wert ist als Geisterlinie sichtbar — damit du siehst, ob '
                'du dich gerade hoch- oder runterlügst.'),
        const SizedBox(height: 24),
        Center(
          child: Text(
            '$_percent%',
            style: TextStyle(
              color: project.category.hue,
              fontSize: 56,
              fontWeight: FontWeight.w800,
              letterSpacing: -2,
            ),
          ),
        ),
        Center(
          child: Text(
            'vorher: $old%',
            style: const TextStyle(color: AppColors.textFaint, fontSize: 13),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ProgressBar(
            percent: _percent,
            color: project.category.hue,
            staleness: project.staleness,
            height: 14,
            ghostPercent: old,
          ),
        ),
        Slider(
          value: _percent.toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          activeColor: project.category.hue,
          label: '$_percent%',
          onChanged: (v) => setState(() => _percent = v.round()),
        ),
        if (_resolved.isEmpty && _percent > old)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
            ),
            child: const Text(
              'Prozent gestiegen, aber kein Delta abgehakt. Beim Abschließen '
              'fragt die App genau einmal nach.',
              style: TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ),
        const SizedBox(height: 16),
        _label('Notiz  ·  optional'),
        TextField(
          controller: _note,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Freier Text.'),
        ),
      ],
    );
  }

  Widget _stepHeader(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      );
}
