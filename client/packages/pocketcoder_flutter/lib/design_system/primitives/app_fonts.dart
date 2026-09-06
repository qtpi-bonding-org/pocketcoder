import 'package:flutter/material.dart';
import 'app_sizes.dart';

/// App typography system
///
/// Refers to font families that should be configured in pubspec.yaml.
class AppFonts {
  /// The single font family used throughout the app
  static const String family = 'Noto Sans Mono';

  /// All font families (single family for the terminal design)
  static const List<String> all = [family];

  static const FontWeight heavy = FontWeight.w700;
  static const FontWeight medium = FontWeight.w400;
  static const FontWeight light = FontWeight.w400;

  static TextTheme get textTheme => TextTheme(
        displayLarge: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: heavy,
          height: AppSizes.lineHeightFactor,
        ),
        displayMedium: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: heavy,
          height: AppSizes.lineHeightFactor,
        ),
        displaySmall: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: heavy,
          height: AppSizes.lineHeightFactor,
        ),
        headlineLarge: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: heavy,
          height: AppSizes.lineHeightFactor,
        ),
        headlineMedium: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: heavy,
          height: AppSizes.lineHeightFactor,
        ),
        headlineSmall: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: heavy,
          height: AppSizes.lineHeightFactor,
        ),
        titleLarge: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: heavy,
          height: AppSizes.lineHeightFactor,
        ),
        titleMedium: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: heavy,
          height: AppSizes.lineHeightFactor,
        ),
        titleSmall: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: heavy,
          height: AppSizes.lineHeightFactor,
        ),
        bodyLarge: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: medium,
          height: AppSizes.lineHeightFactor,
        ),
        bodyMedium: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: medium,
          height: AppSizes.lineHeightFactor,
        ),
        bodySmall: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: medium,
          height: AppSizes.lineHeightFactor,
        ),
        labelLarge: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: medium,
          height: AppSizes.lineHeightFactor,
        ),
        labelMedium: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: medium,
          height: AppSizes.lineHeightFactor,
        ),
        labelSmall: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: medium,
          height: AppSizes.lineHeightFactor,
        ),
      );

  AppFonts._();
}
