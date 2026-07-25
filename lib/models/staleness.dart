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
  /// Steilere Kurve: Sättigung fresh 100%, cool 55%, cracked 22%, dust 6%.
  /// Ein frisches Projekt ist eindeutig farbig, ein verstaubtes monochrom.
  double get desaturation {
    switch (this) {
      case Staleness.frisch:
        return 0.0;
      case Staleness.kuehl:
        return 0.45;
      case Staleness.rissig:
        return 0.78;
      case Staleness.staub:
        return 0.94;
    }
  }

  /// Textdeckkraft-Verlust: fresh 100%, cool 88%, cracked 74%, dust 58%.
  double get dim {
    switch (this) {
      case Staleness.frisch:
        return 0.0;
      case Staleness.kuehl:
        return 0.12;
      case Staleness.rissig:
        return 0.26;
      case Staleness.staub:
        return 0.42;
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
