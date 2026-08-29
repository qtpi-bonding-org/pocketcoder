import 'package:flutter/material.dart';
import 'package:flutter_color_palette/flutter_color_palette.dart';

/// App core color palette
class AppPalette {
  static final IColorPalette primary = AppColorPalette(
    colors: const {
      'color1': Color(0xFF050505),
      'color2': Color(0xFF00FF41),
      'color3': Color(0xFF00B82A),
      'neutral1': Color(0xFF003B00),

      'dangerRed': Color(0xFFFF3333),
      'warningAmber': Color(0xFFFFB100),

      'interactable': Color(0xFF00FF41),

      'info': Color(0xFF00B82A),
      'success': Color(0xFF00FF41),
      'error': Color(0xFFFF3333),
      'warning': Color(0xFFFFB100),

      'destructive': Color(0xFFFF3333),
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
  Color get backgroundPrimary => getColor('color1') ?? const Color(0xFF050505);
  Color get black => getColor('color1') ?? const Color(0xFF050505);

  Color get vividGreen => getColor('color2') ?? const Color(0xFF00FF41);
  Color get phosphorGreen => getColor('color3') ?? const Color(0xFF00B82A);
  Color get traceGreen => getColor('neutral1') ?? const Color(0xFF003B00);

  Color get textPrimary => vividGreen;
  Color get textSecondary => traceGreen;
  Color get primaryColor => phosphorGreen;

  Color get dangerRed => getColor('dangerRed') ?? const Color(0xFFFF3333);
  Color get warningAmber => getColor('warningAmber') ?? const Color(0xFFFFB100);

  Color get interactableColor => getColor('interactable') ?? const Color(0xFF00FF41);

  Color get infoColor => getColor('info') ?? const Color(0xFF00B82A);
  Color get successColor => getColor('success') ?? const Color(0xFF00FF41);
  Color get errorColor => getColor('error') ?? const Color(0xFFFF3333);
  Color get warningColor => getColor('warning') ?? const Color(0xFFFFB100);

  Color get destructiveColor => getColor('destructive') ?? const Color(0xFFFF3333);
}
