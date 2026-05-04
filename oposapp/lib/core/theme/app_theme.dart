import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Tema global de OposApp.
/// Usado en MaterialApp.router → theme: AppTheme.light
abstract final class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.naranja,
      primary: AppColors.naranja,
      onPrimary: Colors.white,
      secondary: AppColors.naranjaOsc,
      onSecondary: Colors.white,
      surface: Colors.white,
      background: AppColors.fondo,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.fondo,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.naranja,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.superficieCrema,
      labelStyle: const TextStyle(color: Colors.black54),
      hintStyle: const TextStyle(color: Colors.black38),
      prefixIconColor: AppColors.naranja,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.bordeNaranja, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.naranja, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge:  TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black87),
      bodySmall:  TextStyle(color: Colors.black54),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.naranja,
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: Color(0x66FF6B00),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        textStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      color: Colors.white,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.superficieCrema,
      labelStyle: const TextStyle(color: AppColors.naranja, fontWeight: FontWeight.w600),
      side: const BorderSide(color: AppColors.naranja),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.naranja,
      foregroundColor: Colors.white,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.naranja),
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith(
          (s) => s.contains(MaterialState.selected) ? AppColors.naranja : null),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: AppColors.naranja,
      unselectedItemColor: Colors.black45,
      backgroundColor: Colors.white,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
