import 'package:flutter/material.dart';

abstract final class PanelColors {
  static const primary = Color(0xFF3E8E7E);
  static const ink = Color(0xFF2F3A56);
  static const inkSoft = Color(0xFF6B7489);
  static const background = Color(0xFFF6F4F0);
  static const line = Color(0xFFE8E4DE);
  static const danger = Color(0xFFD64545);
  static const dangerSoft = Color(0xFFFCE8E6);
  static const warning = Color(0xFFE59A2F);
  static const mint = Color(0xFF8FD3BF);
  static const mintSoft = Color(0xFFE4F4EE);
  static const peach = Color(0xFFF4A285);
  static const peachSoft = Color(0xFFFDE8DF);
  static const sand = Color(0xFFEFC982);
  static const sandSoft = Color(0xFFFBF1DC);
  static const lilacSoft = Color(0xFFEFEAFA);
  static const skySoft = Color(0xFFE5F2FB);
}

ThemeData buildPanelTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(
      seedColor: PanelColors.primary,
      primary: PanelColors.primary,
      error: PanelColors.danger,
    ),
    scaffoldBackgroundColor: PanelColors.background,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: PanelColors.ink,
      displayColor: PanelColors.ink,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: PanelColors.line),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: PanelColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
