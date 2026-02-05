import 'package:flutter/material.dart';
import 'package:flutter_color_palette/flutter_color_palette.dart';

/// App core color palette
class AppPalette {
  static final IColorPalette primary = AppColorPalette(
    colors: const {
      // Core palette (Cyberpunk Terminal)
      'color1': Color(0xFF050505), // Background (Deep Black)
      'color2': Color(0xFF00FF41), // Text (Neon Green)
      'color3': Color(0xFF008F11), // Dimmer Green - Primary/Accent
      'neutral1': Color(0xFF003B00), // Very dim green - Secondary text

      // Interactable color
      'interactable': Color(0xFF00FF41), // Neon Green

      // Semantic colors
      'info': Color(0xFF008F11), // Dim Green
      'success': Color(0xFF00FF41), // Neon Green
      'error': Color(0xFFFF0033), // Terminal Red
      'warning': Color(0xFFFFFF00), // Terminal Yellow

      // Destructive color
      'destructive': Color(0xFFFF0033), // Red
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
