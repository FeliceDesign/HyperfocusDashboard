import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../services/ledger.dart';
import '../theme/app_theme.dart';

/// Beerdigen ist ein echtes Feature mit eigenem Flow, kein Löschen im
/// Kontextmenü. Ein bewusst beerdigtes Projekt ist ein Erfolg, kein Scheitern.
class BurialScreen extends StatefulWidget {
  const BurialScreen({super.key, required this.project});

  final Project project;

  @override
  State<BurialScreen> createState() => _BurialScreenState();
}

class _BurialScreenState extends State<BurialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final _learning = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    _learning.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<Ledger>().buryProject(
          widget.project.id,
          reason: _reason.text,
          learning: _learning.text,
        );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.project.name} beerdigen')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'Ein bewusst beerdigtes Projekt befreit WIP-Kapazität und '
                'beendet den schleichenden Schuldgefühl-Overhead. Es '
                'verschwindet nicht — es bleibt Teil deiner Statistik und '
                'deiner Geschichte.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),
            _label('Warum beerdigt?'),
            TextFormField(
              controller: _reason,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Der Grund.'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ein Grund gehört dazu.' : null,
            ),
            const SizedBox(height: 20),
            _label('Was hast du mitgenommen?'),
            TextFormField(
              controller: _learning,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Das Learning.'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Auch ein totes Projekt hat dir etwas beigebracht.'
                  : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Endgültig beerdigen',
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
