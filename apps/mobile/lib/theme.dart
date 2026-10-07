import 'package:flutter/material.dart';

/// Nesta renk paleti (arayüz tasarımlarındaki pastel tonlar).
abstract final class NestaColors {
  static const primary = Color(0xFF3E8E7E);
  static const primaryDark = Color(0xFF2C6B5E);
  static const ink = Color(0xFF2F3A56);
  static const inkSoft = Color(0xFF6B7489);
  static const background = Color(0xFFFAF8F5);
  static const surface = Colors.white;
  static const line = Color(0xFFE8E4DE);
  static const danger = Color(0xFFD64545);
  static const dangerSoft = Color(0xFFFCE8E6);
  static const warning = Color(0xFFE59A2F);
  static const success = Color(0xFF3E9E6E);

  static const mint = Color(0xFF8FD3BF);
  static const mintSoft = Color(0xFFE4F4EE);
  static const peach = Color(0xFFF4A285);
  static const peachSoft = Color(0xFFFDE8DF);
  static const sand = Color(0xFFEFC982);
  static const sandSoft = Color(0xFFFBF1DC);
  static const lilac = Color(0xFFB9A6E3);
  static const lilacSoft = Color(0xFFEFEAFA);
  static const sky = Color(0xFF8EC6E8);
  static const skySoft = Color(0xFFE5F2FB);

  /// Egzersiz kartı için (koyu, açık) renk çifti.
  static (Color, Color) forKey(String key) => switch (key) {
    'peach' => (peach, peachSoft),
    'sand' => (sand, sandSoft),
    'lilac' => (lilac, lilacSoft),
    'sky' => (sky, skySoft),
    _ => (mint, mintSoft),
  };
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: NestaColors.primary,
    primary: NestaColors.primary,
    surface: NestaColors.surface,
    error: NestaColors.danger,
  );
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: scheme,
    scaffoldBackgroundColor: NestaColors.background,
  );
  final text = base.textTheme.apply(
    bodyColor: NestaColors.ink,
    displayColor: NestaColors.ink,
  );
  return base.copyWith(
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: NestaColors.background,
      foregroundColor: NestaColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        color: NestaColors.ink,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        side: const BorderSide(color: NestaColors.primary),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: NestaColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: NestaColors.line),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: NestaColors.line),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: NestaColors.mintSoft,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
