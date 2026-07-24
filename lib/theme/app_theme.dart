import 'package:flutter/material.dart';

import '../models/staleness.dart';

/// Dunkel, aber nicht das übliche Dev-Tool-Grau. Warmes Anthrazit, damit
/// der Sättigungsverlust der verrottenden Karten überhaupt wirkt.
class AppColors {
  static const background = Color(0xFF17130F);
  static const surface = Color(0xFF211C17);
  static const surfaceRaised = Color(0xFF2A241D);
  static const border = Color(0xFF3A3229);
  static const textPrimary = Color(0xFFEDE6DC);
  static const textSecondary = Color(0xFFA89B8A);
  static const textFaint = Color(0xFF6E6355);

  // Verbindliche Farbsemantik — je Rolle genau eine Farbe:
  /// Interaktiv / Auswahl / Primary: Buttons, aktive Chips, Slider, Picker.
  static const interactive = Color(0xFF37BEB0);

  /// Warnung: Todeszone, WIP-Limit erreicht, altes Delta. Verblasst nie.
  static const deathZone = Color(0xFFCF7A3A);

  /// Harter Negativfakt: "Letzter Abschluss: noch keiner", verhungert.
  static const danger = Color(0xFFE05A4D);
}

class AppTheme {
  static ThemeData build() {
    const base = ColorScheme.dark(
      surface: AppColors.background,
      primary: AppColors.textPrimary,
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
