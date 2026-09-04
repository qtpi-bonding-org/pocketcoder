import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/app_palette.dart';

void main() {
  test('palette is exactly the six specified values', () {
    expect(AppPalette.ground, const Color(0xFF050505));
    expect(AppPalette.trace,  const Color(0xFF003B00));
    expect(AppPalette.dim,    const Color(0xFF00701A));
    expect(AppPalette.body,   const Color(0xFF00B82A));
    expect(AppPalette.bright, const Color(0xFF00FF41));
    expect(AppPalette.amber,  const Color(0xFFFFB100));
    expect(AppPalette.red,    const Color(0xFFFF5555));
  });

  test('red clears 6:1 against the ground', () {
    // Red is the one value tuned for contrast rather than heritage: there was
    // no red monochrome phosphor, and saturated red is the worst-case hue on a
    // dark ground. #FF3333 measured 5.6:1; #FF5555 measures ~6.5:1.
    final ratio = _contrast(AppPalette.red, AppPalette.ground);
    expect(ratio, greaterThan(6.0));
  });

  test('dim is legible as secondary text and trace is not text', () {
    expect(_contrast(AppPalette.dim, AppPalette.ground), greaterThan(2.5));
    expect(_contrast(AppPalette.trace, AppPalette.ground), lessThan(2.0));
  });
}

double _lum(Color c) {
  double ch(int v) {
    final s = v / 255.0;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }
  return 0.2126 * ch(c.red) + 0.7152 * ch(c.green) + 0.0722 * ch(c.blue);
}

double _contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}
