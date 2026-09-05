import 'package:flutter/material.dart';
import 'ui_scaler.dart';

/// Design tokens for all scalable dimensions.
/// Single source of truth for sizes, spacing, radii, and typography scale.
class AppSizes {
  AppSizes._();

  static double get space => UiScaler.instance.px(8.0);

  static double get fontBody => UiScaler.instance.sp(16.0);

  /// Art is exempt from the text scale and sized like an image.
  /// Poco and terminal ASCII art use this to maintain their proportions.
  static double get fontPoco => UiScaler.instance.sp(24.0);

  static List<double> get textSizes => [fontBody];

  /// Measured character advance width of the monospace body font.
  /// Cached after first access to avoid repeated TextPainter measurements.
  static final double ch = _measureCh();

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

/// The shipped monospace font's advance ratio -- the width of one character
/// as a fraction of the font size.
///
/// Measured once from the real font rather than assumed, because it is a
/// property of whatever font ships and a constant here would go silently
/// wrong the moment the family changes. Every horizontal grid unit derives
/// from this, so it lives in one place.
///
/// Noto Sans Mono is 600/1000 upm, so this resolves to 0.6.
double get monoAdvanceRatio => _advanceRatio ??= _measureAdvanceRatio();
double? _advanceRatio;

/// The ratio used when the font has not loaded, which happens in a bare
/// widget test with no FontLoader. Deliberately the true value rather than a
/// "safe" smaller one: understating it makes `ch` too small, which makes
/// `contentMaxWidth` too narrow and clamps text early.
const double kFallbackMonoAdvanceRatio = 0.6;

double _measureAdvanceRatio() {
  // Measured at a large size and divided down. Laying out at 1.0 rounds to
  // roughly the font size, which tripped the unloaded-font check below and
  // pinned the ratio at 0.5 -- every grid unit was then 17% short.
  const probeSize = 100.0;
  final painter = TextPainter(
    text: const TextSpan(
      text: 'M',
      style: TextStyle(
        fontFamily: 'Noto Sans Mono',
        fontSize: probeSize,
        fontWeight: FontWeight.w400,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final ratio = painter.width / probeSize;

  // An unloaded font lays out at roughly one em per character. A real
  // monospace advance is well below that, so anything at or above 0.8 means
  // the measurement is of the fallback face, not ours.
  if (ratio >= 0.8) return kFallbackMonoAdvanceRatio;
  return ratio;
}

/// Measure character advance width for a given font size.
/// Exposed for testing to verify real font measurement after font loading.
@visibleForTesting
double measureCharacterAdvance(double fontBodySize) =>
    monoAdvanceRatio * fontBodySize;
