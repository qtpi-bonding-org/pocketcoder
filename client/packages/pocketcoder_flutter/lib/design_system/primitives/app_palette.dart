import 'package:flutter/material.dart';
import 'package:flutter_color_palette/flutter_color_palette.dart';

/// App core color palette
class AppPalette {
  static final IColorPalette primary = AppColorPalette(
    colors: const {
      // Green Hierarchy
      'color1': Color(0xFF050505), // Background (Deep Black)
      'color2': Color(0xFF00FF41), // Vivid Green (High Intesity)
      'color3': Color(0xFF00B82A), // Phosphor Green (Standard Reading)
      'neutral1': Color(0xFF003B00), // Trace Green (Subtle UI)

      // PocketCoder ANSI Accents
      'userCyan': Color(0xFF00FFFF),
      'dangerRed': Color(0xFFFF3333),
      'infoWhite': Color(0xFFE4E4E4),
      'warningAmber': Color(0xFFFFB100),

      // Interactable color
      'interactable': Color(0xFF00FF41), // Vivid Green

      // Semantic colors
      'info': Color(0xFF00B82A), // Phosphor Green
      'success': Color(0xFF00FF41), // Vivid Green
      'error': Color(0xFFFF3333), // Danger Red
      'warning': Color(0xFFFFB100), // Warning Amber

      // Destructive color
      'destructive': Color(0xFFFF3333), // Danger Red
    },
    name: 'PocketCoder Terminal',
  );

  /// Automatic dark mode via luminance inversion
  static IColorPalette get dark => primary.symmetricPalette;
}

/// Extension for semantic color access
extension AppColors on IColorPalette {
  // Background & Surface
  Color get backgroundPrimary => getColor('color1') ?? const Color(0xFF050505);
  Color get black => getColor('color1') ?? const Color(0xFF050505);

  // Green Hierarchy
  Color get vividGreen => getColor('color2') ?? const Color(0xFF00FF41);
  Color get phosphorGreen => getColor('color3') ?? const Color(0xFF00B82A);
  Color get traceGreen => getColor('neutral1') ?? const Color(0xFF003B00);

  // Legacy mappings for stability
  Color get textPrimary => vividGreen;
  Color get textSecondary => traceGreen;
  Color get primaryColor => phosphorGreen;

  // ANSI Accents
  Color get userCyan => getColor('userCyan') ?? const Color(0xFF00FFFF);
  Color get dangerRed => getColor('dangerRed') ?? const Color(0xFFFF3333);
  Color get infoWhite => getColor('infoWhite') ?? const Color(0xFFE4E4E4);
  Color get warningAmber => getColor('warningAmber') ?? const Color(0xFFFFB100);

  // Interactable
  Color get interactableColor => getColor('interactable') ?? const Color(0xFF00FF41);

  // Semantic colors
  Color get infoColor => getColor('info') ?? const Color(0xFF00B82A);
  Color get successColor => getColor('success') ?? const Color(0xFF00FF41);
  Color get errorColor => getColor('error') ?? const Color(0xFFFF3333);
  Color get warningColor => getColor('warning') ?? const Color(0xFFFFB100);

  // Destructive color
  Color get destructiveColor => getColor('destructive') ?? const Color(0xFFFF3333);
}
