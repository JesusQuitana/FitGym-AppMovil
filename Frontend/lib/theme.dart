import 'package:flutter/material.dart';

class FitColors {
  static const primary = Color(0xFFFF5A1F);
  static const background = Color(0xFF0E1015);
  static const surface = Color(0xFF181B23);
  static const surfaceHigh = Color(0xFF222632);
  static const textMuted = Color(0xFF9AA0AE);

  static const vip = Color(0xFFFFC23D);
  static const premium = Color(0xFF8C6CFF);
  static const regular = Color(0xFF2EC4B6);

  static const ok = Color(0xFF34C77B);
  static const warning = Color(0xFFFFA62B);
  static const danger = Color(0xFFFF4D5E);
}

ThemeData buildFitTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: FitColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: FitColors.primary,
    onPrimary: Colors.white,
    surface: FitColors.surface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: FitColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: FitColors.background,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
