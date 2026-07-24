import 'package:flutter/material.dart';

/// Lebenszyklus eines Projekts.
enum ProjectStatus {
  aktiv,
  pausiert,
  verhungert,
  abgeschlossen,
  beerdigt;

  String get label {
    switch (this) {
      case ProjectStatus.aktiv:
        return 'aktiv';
      case ProjectStatus.pausiert:
        return 'pausiert';
      case ProjectStatus.verhungert:
        return 'verhungert';
      case ProjectStatus.abgeschlossen:
        return 'abgeschlossen';
      case ProjectStatus.beerdigt:
        return 'beerdigt';
    }
  }

  /// Zählt dieses Projekt gegen das WIP-Limit?
  /// Aktiv und verhungert zählen — pausiert, abgeschlossen und beerdigt nicht.
  bool get countsAgainstWip =>
      this == ProjectStatus.aktiv || this == ProjectStatus.verhungert;

  /// Steht das Projekt noch offen auf dem Dashboard?
  bool get isLive =>
      this == ProjectStatus.aktiv ||
      this == ProjectStatus.verhungert ||
      this == ProjectStatus.pausiert;

  static ProjectStatus fromName(String name) => ProjectStatus.values
      .firstWhere((e) => e.name == name, orElse: () => ProjectStatus.aktiv);
}

/// Projekt-Kategorien. Farbe ist Information, nicht Dekoration —
/// jede Kategorie hat einen Farbton, der durch Staleness entzogen wird.
enum Category {
  code('Code', Color(0xFF4FD1C5)),
  foto('Foto', Color(0xFFF6AD55)),
  design('Design', Color(0xFFB794F4)),
  schreiben('Schreiben', Color(0xFF68D391)),
  andere('Andere', Color(0xFFA0AEC0));

  const Category(this.label, this.hue);

  final String label;
  final Color hue;

  static Category fromName(String name) => Category.values
      .firstWhere((e) => e.name == name, orElse: () => Category.andere);
}

/// Richtung der letzten Check-ins.
enum Momentum {
  up('↗'),
  flat('→'),
  down('↘');

  const Momentum(this.arrow);
  final String arrow;
}
