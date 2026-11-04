import 'package:flutter/material.dart';

/// Paleta do universo rodoviário: petróleo (asfalto molhado) e âmbar (sinalização).
/// Contrastes verificados para leitura em sol forte, dentro da boleia.
class AppColors {
  static const ink = Color(0xFF12343B);
  static const amber = Color(0xFFF2A71B);
  static const paper = Color(0xFFF5F6F3);
  static const line = Color(0xFFD9DFDB);
  static const muted = Color(0xFF55666A);
  static const positive = Color(0xFF1F7A4D);
  static const negative = Color(0xFFB3261E);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.ink).copyWith(
    primary: AppColors.ink,
    onPrimary: Colors.white,
    secondary: AppColors.amber,
    onSecondary: AppColors.ink,
    error: AppColors.negative,
    surface: Colors.white,
  );
  const radius = BorderRadius.all(Radius.circular(12));
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: radius, borderSide: BorderSide(color: c, width: w));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: border(AppColors.line),
      enabledBorder: border(AppColors.line),
      focusedBorder: border(AppColors.ink, 2),
      errorBorder: border(AppColors.negative),
      focusedErrorBorder: border(AppColors.negative, 2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: const RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.amber,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.amber,
      foregroundColor: AppColors.ink,
    ),
  );
}
