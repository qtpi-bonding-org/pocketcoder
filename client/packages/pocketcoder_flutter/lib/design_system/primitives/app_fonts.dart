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

  static const FontWeight heavy = FontWeight.w800;
  static const FontWeight medium = FontWeight.w400;
  static const FontWeight light = FontWeight.w200;

  static TextTheme get textTheme => TextTheme(
        displayLarge: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: heavy,
          height: 1.3,
        ),
        displayMedium: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: heavy,
          height: 1.3,
        ),
        displaySmall: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: heavy,
          height: 1.3,
        ),
        headlineLarge: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: heavy,
          height: 1.3,
        ),
        headlineMedium: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: heavy,
          height: 1.3,
        ),
        headlineSmall: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: heavy,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: heavy,
          height: 1.3,
        ),
        titleMedium: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: heavy,
          height: 1.3,
        ),
        titleSmall: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: heavy,
          height: 1.3,
        ),

        bodyLarge: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: medium,
          height: 1.3,
        ),
        bodyMedium: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: medium,
          height: 1.3,
        ),
        bodySmall: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: medium,
          height: 1.3,
        ),

        labelLarge: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: medium,
          height: 1.3,
        ),
        labelMedium: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: medium,
          height: 1.3,
        ),
        labelSmall: TextStyle(
          fontFamily: family,
          fontSize: AppSizes.fontBody,
          fontWeight: medium,
          height: 1.3,
        ),
      );

  AppFonts._();
}
