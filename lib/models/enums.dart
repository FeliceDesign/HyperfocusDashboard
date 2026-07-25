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
  code('Code', Color(0xFF6E93A8)),
  foto('Foto', Color(0xFF8C8AA8)),
  design('Design', Color(0xFF7FA394)),
  schreiben('Schreiben', Color(0xFF8E9AA6)),
  andere('Andere', Color(0xFF6F757C));

  const Category(this.label, this.hue);

  final String label;
  final Color hue;

  static Category fromName(String name) => Category.values
      .firstWhere((e) => e.name == name, orElse: () => Category.andere);
}

/// Richtung der letzten Check-ins.
/// Richtung der letzten Check-ins. Die Darstellung erfolgt über monochrome
/// Vektor-Glyphen (siehe widgets/glyphs.dart), nicht über Emoji-Zeichen.
enum Momentum { up, flat, down }
