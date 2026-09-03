import 'package:flutter/material.dart';
import 'package:flutter_color_palette/flutter_color_palette.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import '../primitives/app_palette.dart';
import '../primitives/app_fonts.dart';
import '../primitives/app_sizes.dart';
export '../primitives/app_palette.dart';
export '../primitives/app_fonts.dart';
export '../primitives/app_sizes.dart';
export '../primitives/app_motion.dart';
export '../primitives/spacers.dart';

/// How an element should read: not yet acted on (plain), the recommended
/// next action or current reading-position (outlined), or already-true --
/// the active tab, a sent message, the user's current selection (selected).
/// Per the emphasis-states spec (2026-08-23), `outlined` is deliberately NOT
/// a variant of `selected` -- applying the invert treatment to a button you
/// haven't pressed yet reads as "you're already here," which is wrong for a
/// primary CTA or a stepper's current-position marker.
enum Emphasis { plain, outlined, selected }

/// Given a color and how this instance should read, returns what to
/// render. This is the ONLY place "invert" or "outline" happens -- every
/// emphasis-aware widget (TerminalFooter's tab buttons, a primary CTA not
/// yet pressed, the chat transcript's user-turn rows, a stepper's
/// current-position marker) calls this directly and inline, passing its
/// own base color and the Emphasis it already knows, instead of hand-
/// rolling its own two- or three-way ternary -- which is exactly how
/// `attention`/`userCyan` diverged in the color-system spec's audit.
({Color? fill, Color? border, Color text}) emphasize(
  Color base,
  Emphasis emphasis,
) =>
    switch (emphasis) {
      Emphasis.plain => (fill: null, border: null, text: base),
      Emphasis.outlined => (fill: null, border: base, text: base),
      Emphasis.selected => (fill: base, border: null, text: Colors.black),
    };

/// Extension for terminal-specific colors that don't fit into standard ColorScheme.
class TerminalColors extends ThemeExtension<TerminalColors> {
  final Color glow;

  final Color danger;
  final Color warning;

  const TerminalColors({
    required this.glow,
    required this.danger,
    required this.warning,
  });

  @override
  TerminalColors copyWith({
    Color? glow,
    Color? danger,
    Color? warning,
  }) {
    return TerminalColors(
      glow: glow ?? this.glow,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
    );
  }

  @override
  TerminalColors lerp(ThemeExtension<TerminalColors>? other, double t) {
    if (other is! TerminalColors) return this;
    return TerminalColors(
      glow: Color.lerp(glow, other.glow, t) ?? glow,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
    );
  }
}

/// App theme implementation
class AppTheme {
  /// The one PocketCoder look: phosphor green on deep black.
  ///
  /// A CRT terminal has a single appearance, so both [lightTheme] and
  /// [darkTheme] resolve here and the app pins `ThemeMode.dark`. The two
  /// getters are kept as separate entry points so a genuine light theme can
  /// later be authored by pointing [lightTheme] at its own palette — no
  /// rewiring of `MaterialApp` or call sites required.
  static ThemeData get terminalTheme =>
      _buildTheme(AppPalette.primary, brightness: Brightness.dark);

  /// Currently identical to [terminalTheme]. See the note above before
  /// changing this: it is the designated hook for a future light palette.
  static ThemeData get lightTheme => terminalTheme;

  static ThemeData get darkTheme => terminalTheme;

  static ThemeData _buildTheme(
    IColorPalette palette, {
    required Brightness brightness,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      extensions: [
        TerminalColors(
          glow: palette.vividGreen.withValues(alpha: 0.1),
          danger: palette.dangerRed,
          warning: palette.warningAmber,
        ),
      ],
      textTheme: AppFonts.textTheme.apply(
        bodyColor: palette.phosphorGreen,
        displayColor: palette.vividGreen,
        fontFamily: AppFonts.bodyFamily,
        package: 'pocketcoder_flutter',
      ),
      colorScheme: ColorScheme(
        brightness: brightness,
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
          foregroundColor: const Color(0xFF000000),
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
  TerminalColors get terminalColors {
    final ext = theme.extension<TerminalColors>();
    if (ext == null) throw StateError('TerminalColors not registered in theme');
    return ext;
  }

  /// Shorthand for [AppLocalizations.of(this)].
  AppLocalizations get l10n {
    final l10n = AppLocalizations.of(this);
    if (l10n == null) {
      throw StateError(
          'AppLocalizations not found. Ensure localization delegates are configured.');
    }
    return l10n;
  }
}
