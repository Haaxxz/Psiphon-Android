import 'package:flutter/material.dart';

class PsiphonPalette {
  const PsiphonPalette._();

  static const Color background = Color(0xFF000000);
  static const Color sheetBackground = Color(0xFF111114);
  static const Color surface = Color(0xFF1C1C1E);
  static const Color surfaceElevated = Color(0xFF2C2C2E);
  static const Color border = Color(0x24FFFFFF);
  static const Color borderStrong = Color(0x40FFFFFF);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E8E93);

  // Authentic Psiphon 4 radial orb gradient stops
  static const Color orbCoral = Color(0xFFFF703C);
  static const Color orbGold = Color(0xFFFCB569);
  static const Color orbPeach = Color(0xFFEFD4C2);
  static const Color orbPeriwinkle = Color(0xFFAFBADA);

  // Status & telemetry accents
  static const Color connectedEmerald = Color(0xFF2EC27E);
  static const Color connectingAmber = Color(0xFFFFB020);
  static const Color errorCrimson = Color(0xFFE01B24);
  static const Color stopRed = Color(0xFFE02626);
  static const Color uploadCyan = Color(0xFF33B5E5);
}

ThemeData buildPsiphonTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: PsiphonPalette.background,
    colorScheme: const ColorScheme.dark(
      primary: PsiphonPalette.orbCoral,
      secondary: PsiphonPalette.connectedEmerald,
      surface: PsiphonPalette.surface,
      error: PsiphonPalette.errorCrimson,
      onPrimary: Colors.white,
      onSurface: PsiphonPalette.textPrimary,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: PsiphonPalette.sheetBackground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: PsiphonPalette.surfaceElevated,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
