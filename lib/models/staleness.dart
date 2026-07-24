/// Visueller Verfall — Karten verlieren Belichtung, je länger sie liegen.
/// Gerechnet ab dem letzten Check-in mit *tatsächlicher Veränderung*.
enum Staleness {
  frisch, // 0–6 Tage
  kuehl, // 7–13 Tage
  rissig, // 14–29 Tage
  staub; // 30+ Tage

  String get label {
    switch (this) {
      case Staleness.frisch:
        return 'Frisch';
      case Staleness.kuehl:
        return 'Kühl';
      case Staleness.rissig:
        return 'Rissig';
      case Staleness.staub:
        return 'Staub';
    }
  }

  /// Wie stark die Sättigung entzogen wird (0 = volle Farbe, 1 = monochrom).
  double get desaturation {
    switch (this) {
      case Staleness.frisch:
        return 0.0;
      case Staleness.kuehl:
        return 0.30;
      case Staleness.rissig:
        return 0.60;
      case Staleness.staub:
        return 0.90;
    }
  }

  /// Zusätzliche Abdunklung des Texts / der Karte.
  double get dim {
    switch (this) {
      case Staleness.frisch:
        return 0.0;
      case Staleness.kuehl:
        return 0.12;
      case Staleness.rissig:
        return 0.28;
      case Staleness.staub:
        return 0.45;
    }
  }

  bool get hasCrack => this == Staleness.rissig || this == Staleness.staub;
  bool get hasGrain => this == Staleness.staub;

  static Staleness fromDays(int days) {
    if (days <= 6) return Staleness.frisch;
    if (days <= 13) return Staleness.kuehl;
    if (days <= 29) return Staleness.rissig;
    return Staleness.staub;
  }
}
