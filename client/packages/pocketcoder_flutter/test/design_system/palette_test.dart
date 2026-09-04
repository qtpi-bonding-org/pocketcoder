import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/app_palette.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';

void main() {
  test('palette is exactly the six specified values', () {
    expect(AppPalette.ground, const Color(0xFF050505));
    expect(AppPalette.trace, const Color(0xFF003B00));
    expect(AppPalette.dim, const Color(0xFF00701A));
    expect(AppPalette.body, const Color(0xFF00B82A));
    expect(AppPalette.bright, const Color(0xFF00FF41));
    expect(AppPalette.amber, const Color(0xFFFFB100));
    expect(AppPalette.red, const Color(0xFFFF5555));
  });

  test('red clears 6:1 against the ground', () {
    // Red is the one value tuned for contrast rather than heritage: there was
    // no red monochrome phosphor, and saturated red is the worst-case hue on a
    // dark ground. #FF3333 measured 5.6:1; #FF5555 measures ~6.5:1.
    final ratio = _contrast(AppPalette.red, AppPalette.ground);
    expect(ratio, greaterThan(6.0));
  });

  test('dim and trace are usable as non-text tokens but not text', () {
    // dim: the decision-dialog border. trace: the code-surface gutter.
    // Neither clears the 4.5:1 AA floor for text.
    expect(_contrast(AppPalette.dim, AppPalette.ground), greaterThan(2.5));
    expect(_contrast(AppPalette.dim, AppPalette.ground), lessThan(4.5));
    expect(_contrast(AppPalette.trace, AppPalette.ground), lessThan(2.0));
  });

  test('every TextRole colour clears 4.5:1 AA contrast against ground', () {
    for (final role in TextRole.values) {
      final ratio = _contrast(role.color, AppPalette.ground);
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason:
            'TextRole.${role.name} (${role.color}) is ${ratio.toStringAsFixed(2)}:1 '
            'against ground -- below the 4.5:1 AA floor for text',
      );
    }
  });

  test('no TextRole resolves to dim or trace', () {
    for (final role in TextRole.values) {
      expect(
        role.color,
        isNot(AppPalette.dim),
        reason: 'TextRole.${role.name} must not resolve to dim (non-text token only)',
      );
      expect(
        role.color,
        isNot(AppPalette.trace),
        reason: 'TextRole.${role.name} must not resolve to trace (non-text token only)',
      );
    }
  });
}

double _lum(Color c) {
  double ch(int v) {
    final s = v / 255.0;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * ch(c.red) + 0.7152 * ch(c.green) + 0.0722 * ch(c.blue);
}

double _contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}
