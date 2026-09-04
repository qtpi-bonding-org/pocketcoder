import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Text roles define semantic color and weight combinations for terminal UI text.
///
/// Each role carries exactly two attributes:
/// - A color from the palette (semantic meaning: dim, body, bright, or status colors)
/// - A weight: either w400 (reading roles) or w700 (emphasis/action roles)
///
/// Notably, roles never carry a size. The theme supplies size; roles cannot override it.
enum TextRole {
  /// Colour matches [body] -- the label/value distinction rides on weight,
  /// not hue. `dim` fails WCAG AA contrast (3.23:1) as text and may never be
  /// used for a glyph; it survives only as the decision-dialog border.
  label(AppPalette.body, FontWeight.w400),

  /// Regular body text (e.g., descriptions, instructions).
  body(AppPalette.body, FontWeight.w400),

  /// Important data or values (e.g., file sizes, memory usage) — bold for emphasis.
  value(AppPalette.bright, FontWeight.w700),

  /// Success or positive action (e.g., "done", "running") — bold to signal meaning.
  ok(AppPalette.bright, FontWeight.w700),

  /// Warning state (e.g., "slow", "outdated") — bold to draw attention.
  warn(AppPalette.amber, FontWeight.w700),

  /// Error or failure state (e.g., "failed", "critical") — bold to signal severity.
  fail(AppPalette.red, FontWeight.w700);

  /// The color associated with this role.
  final Color color;

  /// The font weight associated with this role (reading or emphasis).
  final FontWeight weight;

  const TextRole(this.color, this.weight);

  /// Returns a TextStyle configured with this role's color and weight.
  ///
  /// Note: fontSize is intentionally omitted, allowing the theme to supply it.
  /// This enforces the "one size" rule: all text is scaled by the theme, not by role.
  TextStyle get style => TextStyle(
        color: color,
        fontWeight: weight,
      );
}
