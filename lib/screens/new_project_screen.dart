import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../services/ledger.dart';
import '../theme/app_theme.dart';

/// Projekt anlegen. Definition of Done ist Pflicht — die erste Hürde.
class NewProjectScreen extends StatefulWidget {
  const NewProjectScreen({super.key, this.initialName});

  /// Vorbelegter Name — z.B. die Idee, für die gerade Platz geschaffen wurde.
  final String? initialName;

  @override
  State<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends State<NewProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _dod = TextEditingController();
  final _deltas = TextEditingController();
  Category _category = Category.code;
  int _startPercent = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) _name.text = widget.initialName!;
  }

  @override
  void dispose() {
    _name.dispose();
    _dod.dispose();
    _deltas.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final ledger = context.read<Ledger>();
    final deltaLines = _deltas.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    ledger.createProject(
      name: _name.text,
      category: _category,
      definitionOfDone: _dod.text,
      initialDeltas: deltaLines,
      initialPercent: _startPercent > 0 ? _startPercent : null,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Neues Projekt')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _label('Name'),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'z.B. Spektra'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ein Name muss sein.' : null,
            ),
            const SizedBox(height: 20),
            _label('Kategorie'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Category.values.map((c) {
                final selected = c == _category;
                return ChoiceChip(
                  label: Text(c.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = c),
                  showCheckmark: false,
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.surfaceRaised,
                  side: BorderSide(
                    color: selected ? AppColors.ink : AppColors.border,
                  ),
                  labelStyle: TextStyle(
                    color: selected ? AppColors.ink : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _label('Definition of Done  ·  Pflicht'),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Wenn du nicht in einem Satz sagen kannst, wann es fertig ist, '
                'ist es keine Projekt-Idee, sondern eine Stimmung.',
                style: TextStyle(color: AppColors.textFaint, fontSize: 12),
              ),
            ),
            TextFormField(
              controller: _dod,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Ein Satz: Wann ist es fertig?',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Ohne Definition of Done kein Projekt.'
                  : null,
            ),
            const SizedBox(height: 20),
            _label('Offene Deltas  ·  optional'),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Was liegt konkret zwischen jetzt und 100%? Eine Zeile pro Item.',
                style: TextStyle(color: AppColors.textFaint, fontSize: 12),
              ),
            ),
            TextFormField(
              controller: _deltas,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Export-Test fehlt\nDoku-Kapitel 3\nOnboarding-Screen',
              ),
            ),
            const SizedBox(height: 20),
            _label('Gefühlter Startwert  ·  $_startPercent%'),
            Slider(
              value: _startPercent.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              activeColor: AppColors.ink,
              label: '$_startPercent%',
              onChanged: (v) => setState(() => _startPercent = v.round()),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Projekt anlegen',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

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
