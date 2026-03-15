import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

/// Semantic size tokens for terminal text.
enum TerminalTextSize {
  /// 10sp — timestamps, footnotes
  tiny,

  /// 12sp — captions, secondary info
  mini,

  /// 14sp — default body text
  small,

  /// 16sp — emphasized body text
  base,

  /// 24sp — section headings
  large,
}

/// Semantic weight tokens for terminal text.
enum TerminalTextWeight {
  /// w200 — subtle / de-emphasized
  light,

  /// w400 — standard reading weight
  medium,

  /// w800 — labels, headings, emphasis
  heavy,
}

/// A standardised text widget that maps semantic size/weight enums
/// to the design-system tokens in [AppSizes] and [AppFonts].
///
/// Replaces ad-hoc `TextStyle(fontFamily: AppFonts.bodyFamily, …)` patterns.
class TerminalText extends StatelessWidget {
  final String text;
  final TerminalTextSize size;
  final TerminalTextWeight weight;
  final Color? color;

  /// Quick opacity shortcut — applied to [color] (or `onSurface` fallback).
  final double? alpha;
  final double? letterSpacing;
  final double? height;
  final FontStyle? fontStyle;
  final TextOverflow? overflow;
  final int? maxLines;
  final TextAlign? textAlign;

  const TerminalText(
    this.text, {
    super.key,
    this.size = TerminalTextSize.small,
    this.weight = TerminalTextWeight.medium,
    this.color,
    this.alpha,
    this.letterSpacing,
    this.height,
    this.fontStyle,
    this.overflow,
    this.maxLines,
    this.textAlign,
  });

  /// 10sp, medium weight — timestamps, fine-print.
  const TerminalText.tiny(
    this.text, {
    super.key,
    this.color,
    this.alpha,
    this.letterSpacing,
    this.height,
    this.fontStyle,
    this.overflow,
    this.maxLines,
    this.textAlign,
  })  : size = TerminalTextSize.tiny,
        weight = TerminalTextWeight.medium;

  /// 12sp, medium weight — captions, secondary info.
  const TerminalText.mini(
    this.text, {
    super.key,
    this.color,
    this.alpha,
    this.letterSpacing,
    this.height,
    this.fontStyle,
    this.overflow,
    this.maxLines,
    this.textAlign,
  })  : size = TerminalTextSize.mini,
        weight = TerminalTextWeight.medium;

  /// 12sp, heavy weight — section headers, status labels.
  const TerminalText.label(
    this.text, {
    super.key,
    this.color,
    this.alpha,
    this.letterSpacing,
    this.height,
    this.fontStyle,
    this.overflow,
    this.maxLines,
    this.textAlign,
  })  : size = TerminalTextSize.mini,
        weight = TerminalTextWeight.heavy;

  // ---------------------------------------------------------------------------
  // Token mapping helpers
  // ---------------------------------------------------------------------------

  double _resolveSize() => switch (size) {
        TerminalTextSize.tiny => AppSizes.fontTiny,
        TerminalTextSize.mini => AppSizes.fontMini,
        TerminalTextSize.small => AppSizes.fontSmall,
        TerminalTextSize.base => AppSizes.fontStandard,
        TerminalTextSize.large => AppSizes.fontLarge,
      };

  FontWeight _resolveWeight() => switch (weight) {
        TerminalTextWeight.light => AppFonts.light,
        TerminalTextWeight.medium => AppFonts.medium,
        TerminalTextWeight.heavy => AppFonts.heavy,
      };

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final baseColor = color ?? colors.onSurface;
    final effectiveColor =
        alpha != null ? baseColor.withValues(alpha: alpha ?? 1.0) : baseColor;

    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: TextStyle(
        fontFamily: AppFonts.bodyFamily,
        fontSize: _resolveSize(),
        fontWeight: _resolveWeight(),
        color: effectiveColor,
        letterSpacing: letterSpacing,
        height: height,
        fontStyle: fontStyle,
      ),
    );
  }
}
