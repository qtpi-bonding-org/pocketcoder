import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/app_fonts.dart';
import 'package:pocketcoder_flutter/design_system/primitives/app_sizes.dart';

void main() {
  test('there is exactly one font family', () {
    expect(AppFonts.family, 'Noto Sans Mono');
    // Share Tech Mono renders no ASCII art, cannot render box drawing, and
    // exists only to create a font tier a terminal does not have.
    expect(AppFonts.all, hasLength(1));
  });

  test('there is exactly one text size', () {
    expect(AppSizes.fontBody, 16.0);
    expect(AppSizes.textSizes, hasLength(1));
  });

  test('every TextTheme slot uses the one size and the one family', () {
    final theme = AppFonts.textTheme;
    final styles = [
      theme.displayLarge, theme.displayMedium, theme.displaySmall,
      theme.headlineLarge, theme.headlineMedium, theme.headlineSmall,
      theme.titleLarge, theme.titleMedium, theme.titleSmall,
      theme.bodyLarge, theme.bodyMedium, theme.bodySmall,
      theme.labelLarge, theme.labelMedium, theme.labelSmall,
    ];
    for (final s in styles) {
      expect(s!.fontSize, AppSizes.fontBody);
      expect(s.fontFamily, AppFonts.family);
    }
  });
}
