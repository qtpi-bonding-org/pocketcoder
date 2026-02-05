import 'package:flutter/material.dart';
import 'package:flutter_color_palette/flutter_color_palette.dart';

/// App core color palette
class AppPalette {
  static final IColorPalette primary = AppColorPalette(
    colors: const {
      // Core palette (light mode)
      'color1': Color(0xFFFAF7F0), // Background
      'color2': Color(0xFF2B2B2B), // Text
      'color3': Color(0xFF006280), // Teal - Primary
      'neutral1': Color(0xFF4D5B60), // Secondary text

      // Interactable color
      'interactable': Color(0xFF006280),

      // Semantic colors
      'info': Color(0xFFB9D9ED), // Blue
      'success': Color(0xFFCDE8C4), // Green
      'error': Color(0xFFF4C1C1), // Pink
      'warning': Color(0xFFF5E6A3), // Yellow

      // Destructive color
      'destructive': Color(0xFFBC4B41), // Red
    },
    name: 'App Primary',
  );

  /// Automatic dark mode via luminance inversion
  static IColorPalette get dark => primary.symmetricPalette;
}

/// Extension for semantic color access
extension AppColors on IColorPalette {
  // Background & Surface
  Color get backgroundPrimary => getColor('color1')!;

  // Text
  Color get textPrimary => getColor('color2')!;
  Color get textSecondary => getColor('neutral1')!;

  // Accent/Primary action color
  Color get primaryColor => getColor('color3')!;

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
