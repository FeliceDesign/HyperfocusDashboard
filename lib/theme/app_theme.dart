import 'package:flutter/material.dart';

import '../models/staleness.dart';

/// Dunkel, aber nicht das übliche Dev-Tool-Grau. Warmes Anthrazit, damit
/// der Sättigungsverlust der verrottenden Karten überhaupt wirkt.
/// Non Finito — Farbsystem. Grundregel: *Alles Kalte ist neutral, alles Warme
/// ist eine Warnung.* Die Oberfläche ist durchgehend kühles Grau; Wärme
/// erscheint ausschließlich dort, wo etwas nicht stimmt.
class AppColors {
  // Neutrale (kalt)
  static const background = Color(0xFF101215); // --bg
  static const surface = Color(0xFF171A1E); // --surface
  static const surfaceRaised = Color(0xFF1E2227); // --surface-raised
  static const border = Color(0xFF262B31); // --line
  static const textPrimary = Color(0xFFF2F5F7); // --ink
  static const textSecondary = Color(0xFFA6AEB6); // --ink-muted
  static const textFaint = Color(0xFF6B747C); // --ink-dim

  /// Track (ungefüllter Teil) des Fortschrittsbalkens — bewusst heller als
  /// die Kartenoberfläche, damit der gefüllte Teil einen sichtbaren Bezug hat.
  static const progressTrack = Color(0xFF20262C);

  /// Kein Akzent-Farbton: interaktive Elemente sind --ink (nahezu weiß).
  static const interactive = textPrimary;

  // Warnfarben — die einzige Wärme. Werden vom Decay NIE entsättigt.
  /// Todeszone, WIP-Limit erreicht, Delta älter als 30 Tage.
  static const deathZone = Color(0xFFD9A441); // --warn
  /// Verhungert, "Letzter Abschluss: noch keiner".
  static const danger = Color(0xFFD9564A); // --alert

  // Semantische Aliase
  static const ink = textPrimary;
  static const inkMuted = textSecondary;
  static const inkDim = textFaint;
  static const line = border;
  static const warn = deathZone;
  static const alert = danger;
}

/// Prozentwerte und Statistikzahlen mit Tabellenziffern — sonst springen die
/// Zahlen beim Aktualisieren und stehen in Listen nicht bündig.
const List<FontFeature> kTabular = [FontFeature.tabularFigures()];

class AppTheme {
  static ThemeData build() {
    const base = ColorScheme.dark(
      surface: AppColors.background,
      primary: AppColors.textPrimary, // interaktiv = ink
      onPrimary: AppColors.background, // Primary-Button: Text in --bg
      secondary: AppColors.deathZone,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
      splashFactory: NoSplash.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        bodySmall: TextStyle(color: AppColors.textSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.textFaint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

/// Farbe ist Information: der Kategorie-Farbton wird durch Staleness entzogen.
/// Volle Farbe muss man sich verdienen.
Color stalenessColor(Color hue, Staleness staleness) {
  final hsl = HSLColor.fromColor(hue);
  final desaturated = hsl
      .withSaturation((hsl.saturation * (1 - staleness.desaturation))
          .clamp(0.0, 1.0))
      .withLightness((hsl.lightness * (1 - staleness.dim)).clamp(0.0, 1.0));
  return desaturated.toColor();
}
