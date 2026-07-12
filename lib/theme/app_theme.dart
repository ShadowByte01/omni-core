import 'package:flutter/material.dart';
import 'sketchy_constants.dart';

/// The complete "Let's Sketch" ThemeData for OmniCore.
///
/// * Headings → Caveat / Patrick Hand (hand-drawn).
/// * Body     → Inter (clean sans-serif, deep ink black).
/// * Surfaces → off-white paper (#FAFAFA) with sketchy black strokes.
/// * Dark mode→ black chalkboard with white sketchy strokes.
class SketchAppTheme {
  SketchAppTheme._();

  static const String fontHeading = 'Caveat';
  static const String fontHand = 'PatrickHand';
  static const String fontBody = 'Inter';

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final colorScheme = base.colorScheme.copyWith(
      brightness: Brightness.light,
      primary: SketchPalette.inkLight,
      onPrimary: SketchPalette.paperLight,
      secondary: SketchPalette.graphite2,
      onSecondary: SketchPalette.paperLight,
      surface: SketchPalette.paperLight,
      onSurface: SketchPalette.inkLight,
      surfaceContainerHighest: SketchPalette.paperWarm,
      outline: SketchPalette.inkLight,
      outlineVariant: SketchPalette.graphite3,
      inverseSurface: SketchPalette.inkLight,
      onInverseSurface: SketchPalette.paperLight,
    );

    return _base(colorScheme, Brightness.light).copyWith(
      scaffoldBackgroundColor: SketchPalette.paperLight,
      canvasColor: SketchPalette.paperLight,
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final colorScheme = base.colorScheme.copyWith(
      brightness: Brightness.dark,
      primary: SketchPalette.chalkInk,
      onPrimary: SketchPalette.chalkboard,
      secondary: SketchPalette.chalkSoft,
      onSecondary: SketchPalette.chalkboard,
      surface: SketchPalette.chalkboard,
      onSurface: SketchPalette.chalkInk,
      surfaceContainerHighest: SketchPalette.chalkboardDeep,
      outline: SketchPalette.chalkInk,
      outlineVariant: SketchPalette.chalkDim,
      inverseSurface: SketchPalette.chalkInk,
      onInverseSurface: SketchPalette.chalkboard,
    );

    return _base(colorScheme, Brightness.dark).copyWith(
      scaffoldBackgroundColor: SketchPalette.chalkboard,
      canvasColor: SketchPalette.chalkboard,
    );
  }

  static ThemeData _base(ColorScheme scheme, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final ink = isLight ? SketchPalette.inkLight : SketchPalette.chalkInk;
    final sub = isLight ? SketchPalette.graphite3 : SketchPalette.chalkDim;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isLight ? SketchPalette.paperLight : SketchPalette.chalkboard,
      splashFactory: NoSplash.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: _textTheme(ink, sub),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontHeading,
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: ink,
          height: 1.1,
        ),
        iconTheme: IconThemeData(color: ink, size: 26),
      ),
      iconTheme: IconThemeData(color: ink, size: 24),
      dividerTheme: DividerThemeData(
        color: sub.withValues(alpha: 0.4),
        thickness: 1.5,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: ink,
        textColor: ink,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: TextStyle(
          fontFamily: fontHand,
          fontSize: 15,
          color: isLight ? SketchPalette.paperLight : SketchPalette.chalkboard,
        ),
        decoration: BoxDecoration(
          color: ink,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border.all(color: ink, width: 1.8),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: TextStyle(
          fontFamily: fontHand,
          fontSize: 16,
          color:
              isLight ? SketchPalette.paperLight : SketchPalette.chalkboard,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor:
            isLight ? SketchPalette.paperLight : SketchPalette.chalkboard,
        modalBackgroundColor:
            isLight ? SketchPalette.paperLight : SketchPalette.chalkboard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  static TextTheme _textTheme(Color ink, Color sub) {
    final base = TextTheme(
      displayLarge: TextStyle(
        fontFamily: fontHeading,
        fontSize: 56,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.05,
      ),
      displayMedium: TextStyle(
        fontFamily: fontHeading,
        fontSize: 44,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.05,
      ),
      displaySmall: TextStyle(
        fontFamily: fontHeading,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.1,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontHeading,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.15,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontHand,
        fontSize: 22,
        fontWeight: FontWeight.w400,
        color: ink,
        height: 1.2,
      ),
      titleLarge: TextStyle(
        fontFamily: fontHand,
        fontSize: 20,
        fontWeight: FontWeight.w400,
        color: ink,
        height: 1.25,
      ),
      titleMedium: TextStyle(
        fontFamily: fontBody,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ink,
        height: 1.3,
      ),
      titleSmall: TextStyle(
        fontFamily: fontBody,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: ink,
        height: 1.3,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontBody,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: ink,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontBody,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: ink,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontFamily: fontBody,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: sub,
        height: 1.45,
      ),
      labelLarge: TextStyle(
        fontFamily: fontBody,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: ink,
        letterSpacing: 0.2,
      ),
      labelMedium: TextStyle(
        fontFamily: fontBody,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: ink,
        letterSpacing: 0.3,
      ),
      labelSmall: TextStyle(
        fontFamily: fontHand,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: sub,
      ),
    );
    return base;
  }
}
