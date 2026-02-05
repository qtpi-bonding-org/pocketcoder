import 'package:flutter/material.dart';
import 'app_sizes.dart';

/// App typography system
///
/// Refers to font families that should be configured in pubspec.yaml.
class AppFonts {
  /// Header font family
  static const List<String> headerFontFallbacks = [
    'Share Tech Mono',
  ];

  /// Body font family
  static const List<String> bodyFontFallbacks = [
    'Noto Sans Mono',
  ];

  static const String headerFamily = 'Share Tech Mono';
  static const String bodyFamily = 'Noto Sans Mono';

  // Weight Classes
  static const FontWeight heavy = FontWeight.w800; // The Anchor
  static const FontWeight medium = FontWeight.w400; // The Narrative
  static const FontWeight light = FontWeight.w200; // The Whisper

  /// Simplified text theme
  static TextTheme get textTheme => TextTheme(
        // Headers
        displayLarge: TextStyle(
          fontFamilyFallback: headerFontFallbacks,
          fontSize: AppSizes.fontMassive,
          fontWeight: heavy,
        ),
        displayMedium: TextStyle(
          fontFamilyFallback: headerFontFallbacks,
          fontSize: AppSizes.fontMassive,
          fontWeight: heavy,
        ),
        displaySmall: TextStyle(
          fontFamilyFallback: headerFontFallbacks,
          fontSize: AppSizes.fontMassive,
          fontWeight: heavy,
        ),
        headlineLarge: TextStyle(
          fontFamilyFallback: headerFontFallbacks,
          fontSize: AppSizes.fontMassive,
          fontWeight: heavy,
        ),
        headlineMedium: TextStyle(
          fontFamilyFallback: headerFontFallbacks,
          fontSize: AppSizes.fontLarge,
          fontWeight: heavy,
        ),
        headlineSmall: TextStyle(
          fontFamilyFallback: headerFontFallbacks,
          fontSize: AppSizes.fontLarge,
          fontWeight: heavy,
        ),
        titleLarge: TextStyle(
          fontFamilyFallback: headerFontFallbacks,
          fontSize: AppSizes.fontLarge,
          fontWeight: heavy,
        ),
        titleMedium: TextStyle(
          fontFamilyFallback: headerFontFallbacks,
          fontSize: AppSizes.fontStandard,
          fontWeight: heavy,
        ),
        titleSmall: TextStyle(
          fontFamilyFallback: headerFontFallbacks,
          fontSize: AppSizes.fontSmall,
          fontWeight: heavy,
        ),

        // Body
        bodyLarge: TextStyle(
          fontFamilyFallback: bodyFontFallbacks,
          fontSize: AppSizes.fontStandard,
          fontWeight: medium,
        ),
        bodyMedium: TextStyle(
          fontFamilyFallback: bodyFontFallbacks,
          fontSize: AppSizes.fontSmall,
          fontWeight: medium,
        ),
        bodySmall: TextStyle(
          fontFamilyFallback: bodyFontFallbacks,
          fontSize: AppSizes.fontMini,
          fontWeight: medium,
        ),

        // Labels
        labelLarge: TextStyle(
          fontFamilyFallback: bodyFontFallbacks,
          fontSize: AppSizes.fontStandard,
          fontWeight: medium,
        ),
        labelMedium: TextStyle(
          fontFamilyFallback: bodyFontFallbacks,
          fontSize: AppSizes.fontSmall,
          fontWeight: medium,
        ),
        labelSmall: TextStyle(
          fontFamilyFallback: bodyFontFallbacks,
          fontSize: AppSizes.fontMini,
          fontWeight: medium,
        ),
      );

  AppFonts._();
}
