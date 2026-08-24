import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

void main() {
  group('emphasize', () {
    const base = Color(0xFF00B82A);

    test('plain has no fill, no border, base color text', () {
      final result = emphasize(base, Emphasis.plain);
      expect(result.fill, isNull);
      expect(result.border, isNull);
      expect(result.text, base);
    });

    test('outlined has no fill, a base-color border, base color text', () {
      final result = emphasize(base, Emphasis.outlined);
      expect(result.fill, isNull);
      expect(result.border, base);
      expect(result.text, base);
    });

    test('selected has base-color fill, no border, black text', () {
      final result = emphasize(base, Emphasis.selected);
      expect(result.fill, base);
      expect(result.border, isNull);
      expect(result.text, Colors.black);
    });
  });
}
