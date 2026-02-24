import 'package:flutter/material.dart';
import 'package:flutter_color_palette/flutter_color_palette.dart';
import '../primitives/app_palette.dart';
import '../primitives/app_fonts.dart';
import '../primitives/app_sizes.dart';
export '../primitives/app_palette.dart';
export '../primitives/app_fonts.dart';
export '../primitives/app_sizes.dart';
export '../primitives/spacers.dart';

/// Extension for terminal-specific colors that don't fit into standard ColorScheme.
class TerminalColors extends ThemeExtension<TerminalColors> {
  final Color glow;
  final Color scanline;
  final double scanlineOpacity;

  // ANSI Accents
  final Color user;
  final Color danger;
  final Color attention;
  final Color warning;

  const TerminalColors({
    required this.glow,
    required this.scanline,
    required this.scanlineOpacity,
    required this.user,
    required this.danger,
    required this.attention,
    required this.warning,
  });

  @override
  TerminalColors copyWith({
    Color? glow,
    Color? scanline,
    double? scanlineOpacity,
    Color? user,
    Color? danger,
    Color? attention,
    Color? warning,
  }) {
    return TerminalColors(
      glow: glow ?? this.glow,
      scanline: scanline ?? this.scanline,
      scanlineOpacity: scanlineOpacity ?? this.scanlineOpacity,
      user: user ?? this.user,
      danger: danger ?? this.danger,
      attention: attention ?? this.attention,
      warning: warning ?? this.warning,
    );
  }

  @override
  TerminalColors lerp(ThemeExtension<TerminalColors>? other, double t) {
    if (other is! TerminalColors) return this;
    return TerminalColors(
      glow: Color.lerp(glow, other.glow, t)!,
      scanline: Color.lerp(scanline, other.scanline, t)!,
      scanlineOpacity: lerpDouble(scanlineOpacity, other.scanlineOpacity, t)!,
      user: Color.lerp(user, other.user, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      attention: Color.lerp(attention, other.attention, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }

  double? lerpDouble(double? a, double? b, double t) {
    if (a == null && b == null) return null;
    a ??= 0.0;
    b ??= 0.0;
    return a + (b - a) * t;
  }
}

/// App theme implementation
class AppTheme {
  /// Light theme
  static ThemeData get lightTheme => _buildTheme(AppPalette.primary);

  /// Dark theme
  static ThemeData get darkTheme => _buildTheme(AppPalette.dark);

  static ThemeData _buildTheme(IColorPalette palette) {
    final isDark = palette == AppPalette.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      extensions: [
        TerminalColors(
          glow: palette.vividGreen.withValues(alpha: 0.1),
          scanline: palette.vividGreen.withValues(alpha: 0.05),
          scanlineOpacity: 0.05,
          user: palette.userCyan,
          danger: palette.dangerRed,
          attention: palette.infoWhite,
          warning: palette.warningAmber,
        ),
      ],
      textTheme: AppFonts.textTheme.apply(
        bodyColor: palette.phosphorGreen, // Standard reading text
        displayColor: palette.vividGreen, // Headers / Highlights
        fontFamily: AppFonts.bodyFamily,
        package: 'pocketcoder_flutter',
      ),
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: palette.vividGreen,
        onPrimary: palette.backgroundPrimary,
        secondary: palette.phosphorGreen,
        onSecondary: palette.backgroundPrimary,
        error: palette.dangerRed,
        onError: palette.backgroundPrimary,
        surface: palette.backgroundPrimary,
        onSurface: palette.vividGreen,
        primaryContainer: palette.vividGreen.withValues(alpha: 0.1),
        onPrimaryContainer: palette.vividGreen,
      ),
      scaffoldBackgroundColor: palette.backgroundPrimary,
      dividerTheme: DividerThemeData(
        color: palette.vividGreen.withValues(alpha: 0.2),
        thickness: AppSizes.borderWidth,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.vividGreen,
          foregroundColor: const Color(0xFF000000), // True Black
          minimumSize: Size.fromHeight(AppSizes.buttonHeight),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          textStyle: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            fontSize: AppSizes.fontStandard,
            fontWeight: AppFonts.heavy,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: palette.backgroundPrimary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide:
              BorderSide(color: palette.vividGreen.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide:
              BorderSide(color: palette.vividGreen.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: palette.vividGreen,
            width: AppSizes.borderWidthThick,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: palette.dangerRed),
        ),
        contentPadding: EdgeInsets.all(AppSizes.space * 1.5),
        labelStyle: TextStyle(
          color: palette.vividGreen.withValues(alpha: 0.7),
          fontFamily: AppFonts.headerFamily,
          fontSize: AppSizes.fontTiny,
          fontWeight: AppFonts.heavy,
        ),
      ),
    );
  }
}

extension AppThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;
  TerminalColors get terminalColors => theme.extension<TerminalColors>()!;
}
