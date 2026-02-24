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
  Color get backgroundPrimary => getColor('color1')!;
  Color get black => getColor('color1')!;

  // Green Hierarchy
  Color get vividGreen => getColor('color2')!;
  Color get phosphorGreen => getColor('color3')!;
  Color get traceGreen => getColor('neutral1')!;

  // Legacy mappings for stability
  Color get textPrimary => vividGreen;
  Color get textSecondary => traceGreen;
  Color get primaryColor => phosphorGreen;

  // ANSI Accents
  Color get userCyan => getColor('userCyan')!;
  Color get dangerRed => getColor('dangerRed')!;
  Color get infoWhite => getColor('infoWhite')!;
  Color get warningAmber => getColor('warningAmber')!;

  // Interactable
  Color get interactableColor => getColor('interactable')!;

  // Semantic colors
  Color get infoColor => getColor('info')!;
  Color get successColor => getColor('success')!;
  Color get errorColor => getColor('error')!;
  Color get warningColor => getColor('warning')!;

  // Destructive color
  Color get destructiveColor => getColor('destructive')!;
}
