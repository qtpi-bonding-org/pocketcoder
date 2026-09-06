import 'package:flutter/material.dart';
import 'package:flutter_color_palette/flutter_color_palette.dart';

/// App core color palette
class AppPalette {
  // The six roles -- the source of truth from this task onward.
  static const Color ground = Color(0xFF050505);

  /// Non-text token only (1.58:1 against [ground]). The code-surface gutter
  /// is the one place this may be used; no [TextRole] may resolve to it.
  static const Color trace = Color(0xFF003B00);

  /// Non-text token only (3.23:1 against [ground] -- fails WCAG AA for text).
  /// The decision-dialog border is the one place this may be used; no
  /// [TextRole] may resolve to it.
  static const Color dim = Color(0xFF00701A);
  static const Color body = Color(0xFF00B82A);
  static const Color bright = Color(0xFF00FF41);
  static const Color amber = Color(0xFFFFB100);
  static const Color red = Color(0xFFFF5555);

  /// Retained so `_buildTheme` and `ThemeService` keep working. The map is
  /// now derived from the six roles rather than being the source of truth.
  static final IColorPalette primary = AppColorPalette(
    colors: const {
      'color1': ground,
      'color2': bright,
      'color3': body,
      'neutral1': trace,
      'dangerRed': red,
      'warningAmber': amber,
      'interactable': bright,
      'info': body,
      'success': bright,
      'error': red,
      'warning': amber,
      'destructive': red,
    },
    name: 'PocketCoder Terminal',
  );

  /// The alternate palette slot, currently the same phosphor look as
  /// [primary].
  ///
  /// This used to be `primary.symmetricPalette` — a luminance inversion that
  /// produced a white-background "CRT", which is not a look PocketCoder ships.
  /// A genuine alternate (e.g. amber-on-cream) should be hand-authored here as
  /// an explicit colour map and contrast-checked, not derived by inversion.
  static IColorPalette get alternate => primary;
}

/// Extension for semantic color access
extension AppColors on IColorPalette {
  @Deprecated('Use AppPalette.ground instead')
  Color get backgroundPrimary => AppPalette.ground;

  @Deprecated('Use AppPalette.ground instead')
  Color get black => AppPalette.ground;

  @Deprecated('Use AppPalette.bright instead')
  Color get vividGreen => AppPalette.bright;

  @Deprecated('Use AppPalette.body instead')
  Color get phosphorGreen => AppPalette.body;

  @Deprecated('Use AppPalette.trace instead')
  Color get traceGreen => AppPalette.trace;

  @Deprecated('Use AppPalette.bright instead')
  Color get textPrimary => AppPalette.bright;

  @Deprecated('Use AppPalette.trace instead')
  Color get textSecondary => AppPalette.trace;

  @Deprecated('Use AppPalette.body instead')
  Color get primaryColor => AppPalette.body;

  @Deprecated('Use AppPalette.red instead')
  Color get dangerRed => AppPalette.red;

  @Deprecated('Use AppPalette.amber instead')
  Color get warningAmber => AppPalette.amber;

  @Deprecated('Use AppPalette.bright instead')
  Color get interactableColor => AppPalette.bright;

  @Deprecated('Use AppPalette.body instead')
  Color get infoColor => AppPalette.body;

  @Deprecated('Use AppPalette.bright instead')
  Color get successColor => AppPalette.bright;

  @Deprecated('Use AppPalette.red instead')
  Color get errorColor => AppPalette.red;

  @Deprecated('Use AppPalette.amber instead')
  Color get warningColor => AppPalette.amber;

  @Deprecated('Use AppPalette.red instead')
  Color get destructiveColor => AppPalette.red;
}
