import 'package:flutter/material.dart';

abstract final class Palette {
  static const background = Color(0xffF3F5F4);
  static const paper = Color(0xffFFFFFF);
  static const ink = Color(0xff0E221D);
  static const muted = Color(0xff3E544D);
  static const teal = Color(0xff136F5E);
  static const forest = Color(0xff124D42);
  static const mint = Color(0xffDDEDE6);
  static const line = Color(0xffD4DFD8);
  static const brass = Color(0xffE5C89D);
  static const blue = Color(0xff3B6179);
  static const blueWash = Color(0xffE7EFF2);
  static const amber = Color(0xff8A5A10);
  static const amberWash = Color(0xffF9EFDA);
  static const coral = Color(0xffA1452C);
  static const coralWash = Color(0xffFAEAE4);
  static const danger = Color(0xff963B36);
}

@immutable
class SchooldayTokens extends ThemeExtension<SchooldayTokens> {
  const SchooldayTokens._(this._night);
  static const light = SchooldayTokens._(0);
  static const dark = SchooldayTokens._(1);
  final double _night;

  Color _tone(Color day, Color night) => _night == 0
      ? day
      : _night == 1
      ? night
      : Color.lerp(day, night, _night)!;
  Color get background => _tone(Palette.background, const Color(0xff0E1916));
  Color get paper => _tone(Palette.paper, const Color(0xff162621));
  Color get ink => _tone(Palette.ink, const Color(0xffEDF3F0));
  Color get muted => _tone(Palette.muted, const Color(0xffA8BDB5));
  Color get teal => _tone(Palette.teal, const Color(0xff4CC2A8));
  Color get forest => _tone(Palette.forest, const Color(0xff154C42));
  Color get mint => _tone(Palette.mint, const Color(0xff203D33));
  Color get line => _tone(Palette.line, const Color(0xff375046));
  Color get brass => _tone(Palette.brass, const Color(0xffE5C89D));
  Color get blue => _tone(Palette.blue, const Color(0xffA1C7DF));
  Color get blueWash => _tone(Palette.blueWash, const Color(0xff273944));
  Color get amber => _tone(Palette.amber, const Color(0xffE6B55E));
  Color get amberWash => _tone(Palette.amberWash, const Color(0xff392F1E));
  Color get coral => _tone(Palette.coral, const Color(0xffE38C74));
  Color get coralWash => _tone(Palette.coralWash, const Color(0xff3D2B25));
  Color get danger => _tone(Palette.danger, const Color(0xffFFABA4));
  Color resolve(Color color) => switch (color) {
    Palette.background => background,
    Palette.paper => paper,
    Palette.ink => ink,
    Palette.muted => muted,
    Palette.teal => teal,
    Palette.forest => forest,
    Palette.mint => mint,
    Palette.line => line,
    Palette.brass => brass,
    Palette.blue => blue,
    Palette.blueWash => blueWash,
    Palette.amber => amber,
    Palette.amberWash => amberWash,
    Palette.coral => coral,
    Palette.coralWash => coralWash,
    Palette.danger => danger,
    _ => color,
  };
  @override
  SchooldayTokens copyWith() => this;
  @override
  SchooldayTokens lerp(SchooldayTokens? other, double t) => other == null
      ? this
      : SchooldayTokens._(_night + (other._night - _night) * t);
}

extension SchooldayThemeContext on BuildContext {
  SchooldayTokens get tones =>
      Theme.of(this).extension<SchooldayTokens>() ?? SchooldayTokens.light;
}

ThemeData schooldayTheme([Brightness brightness = Brightness.light]) {
  final tone = brightness == Brightness.dark
      ? SchooldayTokens.dark
      : SchooldayTokens.light;
  final base = ThemeData(
    brightness: brightness,
    extensions: [tone],
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: tone.teal,
      primary: tone.teal,
      surface: tone.paper,
      onPrimary: brightness == Brightness.dark ? tone.background : Colors.white,
      onSurface: tone.ink,
      error: tone.danger,
    ),
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: tone.background,
  );
  return base.copyWith(
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tone.forest,
      indicatorColor: const Color(0xffbce1ce),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (state) => IconThemeData(
          color: state.contains(WidgetState.selected)
              ? Palette.ink
              : Colors.white,
          size: 21,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: tone.forest,
      indicatorColor: const Color(0xffbce1ce),
      selectedIconTheme: const IconThemeData(color: Palette.ink),
      unselectedIconTheme: const IconThemeData(color: Colors.white),
      selectedLabelTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: const TextStyle(color: Colors.white),
    ),

    textTheme: base.textTheme.apply(
      bodyColor: tone.ink,
      displayColor: tone.ink,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: tone.background,
      foregroundColor: tone.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 18,
    ),
    dividerTheme: DividerThemeData(color: tone.line, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tone.paper,
      hintStyle: TextStyle(color: tone.muted, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: tone.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: tone.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: tone.teal, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: tone.danger),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 54),
        backgroundColor: tone.forest,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: tone.ink,
        minimumSize: const Size(48, 52),
        side: BorderSide(color: tone.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        textStyle: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: tone.forest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentTextStyle: TextStyle(
        fontFamily: 'Manrope',
        color: Colors.white,
        fontSize: 13,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tone.background,
      showDragHandle: true,
      modalBarrierColor: Color(0x660D241D),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: tone.teal),
  );
}
