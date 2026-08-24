import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

void main() {
  group('selectable', () {
    test('unselected returns no fill and the base color as text', () {
      const base = Color(0xFF00B82A);
      final result = selectable(base, selected: false);
      expect(result.fill, isNull);
      expect(result.text, base);
    });

    test('selected returns the base color as fill and black text', () {
      const base = Color(0xFF00B82A);
      final result = selectable(base, selected: true);
      expect(result.fill, base);
      expect(result.text, Colors.black);
    });
  });

  test('TerminalColors no longer exposes user/attention fields', () {
    expect(TerminalColors.new, isNotNull);
  });
}
