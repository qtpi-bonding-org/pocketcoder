import 'package:flutter/material.dart';
import 'ui_scaler.dart';

/// Design tokens for all scalable dimensions.
/// Single source of truth for sizes, spacing, radii, and typography scale.
class AppSizes {
  AppSizes._();

  static double get space => UiScaler.instance.px(8.0);

  static double get fontBody => UiScaler.instance.sp(16.0);

  static List<double> get textSizes => [fontBody];

  /// Measured character advance width of the monospace body font.
  /// Cached after first access to avoid repeated TextPainter measurements.
  static late final double ch = _measureCh();

  /// Declared line height factor for vertical grid alignment.
  static const double lineHeightFactor = 1.3;

  /// Derived line height from body font size and line height factor.
  static double get line => fontBody * lineHeightFactor;

  /// Measure the advance width of a single character 'M' in the body style.
  /// Noto Sans Mono is the body font; measured directly to avoid circular imports.
  /// Uses a base font size of 1.0 to avoid issues with font loading in tests.
  static double _measureCh() => measureCharacterAdvance(fontBody);

  static double get iconTiny => UiScaler.instance.sp(8.0);
  static double get iconSmall => UiScaler.instance.sp(16.0);
  static double get iconMedium => UiScaler.instance.sp(24.0);
  static double get iconLarge => UiScaler.instance.sp(32.0);
  static double get iconXLarge => UiScaler.instance.sp(48.0);

  static double get radiusTiny => space * 0.25;
  static double get radiusSmall => space;
  static double get radiusMedium => space * 2;
  static double get radiusLarge => space * 3;

  static double get buttonHeight => space * 6;
  static double get inputHeight => space * 7;
  static double get appBarHeight => space * 7;
  static double get bottomBarHeight => space * 10;
  static double get contentMaxWidth => ch * 44;
  static double get pickerHeight => line * 12;
  static double get progressIndicatorSize => space * 1.5;
  static double get progressBarHeight => UiScaler.instance.px(4.0);
  static double get provisioningSnippetPreviewMaxHeight => 176;
  static double get provisioningSnippetMaxHeight => 320;

  static double get borderWidth => UiScaler.instance.px(1.0);
  static double get borderWidthThick => UiScaler.instance.px(2.0);
}

/// Measure character advance width for a given font size.
/// Exposed for testing to verify real font measurement after font loading.
@visibleForTesting
double measureCharacterAdvance(double fontBodySize) {
  const fontFamily = 'Noto Sans Mono';
  const baseFontSize = 1.0;
  final painter = TextPainter(
    text: const TextSpan(
      text: 'M',
      style: TextStyle(
        fontFamily: fontFamily,
        fontSize: baseFontSize,
        fontWeight: FontWeight.w400,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  double charWidth = painter.width;

  // If font isn't loaded, TextPainter returns width equal to font size (1.0).
  // The 0.8 threshold detects this: an unloaded font gives ratio 1.0, so any
  // measured width >= 0.8 is treated as a fallback case. Real Noto Sans Mono
  // has advance ratio ~0.5-0.6, well below this threshold. When fallback is
  // triggered, use the conservative 0.5 ratio (design requirement: 36-column
  // floor at narrowest device width).
  if (charWidth >= baseFontSize * 0.8) {
    charWidth = baseFontSize * 0.5;
  }

  // Scale to actual font size
  return charWidth * fontBodySize;
}
