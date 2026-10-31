import 'package:flutter/material.dart';

abstract final class Palette {
  static const background = Color(0xFFF7F9F5);
  static const paper = Color(0xFFFFFFFF);
  static const ink = Color(0xFF173E36);
  static const muted = Color(0xFF64776D);
  static const teal = Color(0xFF167B68);
  static const forest = Color(0xFF125B4D);
  static const mint = Color(0xFFE8F2EB);
  static const line = Color(0xFFE2E9E1);
  static const blue = Color(0xFF5A759E);
  static const blueWash = Color(0xFFEDF1F8);
  static const amber = Color(0xFF9E732E);
  static const amberWash = Color(0xFFFBF0DB);
  static const coral = Color(0xFFAF6A52);
  static const coralWash = Color(0xFFF9EEE8);
  static const danger = Color(0xFFA64040);
}

ThemeData schooldayTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Palette.teal,
      primary: Palette.teal,
      surface: Palette.background,
      onSurface: Palette.ink,
      error: Palette.danger,
    ),
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: Palette.background,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: Palette.ink,
      displayColor: Palette.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.background,
      foregroundColor: Palette.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    dividerTheme: const DividerThemeData(color: Palette.line, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.paper,
      hintStyle: const TextStyle(color: Palette.muted, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Palette.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Palette.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Palette.teal, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Palette.danger),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 54),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.ink,
        minimumSize: const Size(48, 52),
        side: const BorderSide(color: Palette.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentTextStyle: const TextStyle(
        fontFamily: 'Manrope',
        color: Colors.white,
        fontSize: 13,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.background,
      showDragHandle: true,
      modalBarrierColor: Color(0x660D241D),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Palette.teal,
    ),
  );
}
