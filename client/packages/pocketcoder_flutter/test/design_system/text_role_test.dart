import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/app_palette.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';

void main() {
  test('roles map to the specified colors', () {
    expect(TextRole.label.color,  AppPalette.dim);
    expect(TextRole.body.color,   AppPalette.body);
    expect(TextRole.value.color,  AppPalette.bright);
    expect(TextRole.ok.color,     AppPalette.bright);
    expect(TextRole.warn.color,   AppPalette.amber);
    expect(TextRole.fail.color,   AppPalette.red);
  });

  test('emphasis roles are bold and reading roles are not', () {
    expect(TextRole.label.weight, FontWeight.w400);
    expect(TextRole.body.weight,  FontWeight.w400);
    for (final r in [TextRole.value, TextRole.ok, TextRole.warn, TextRole.fail]) {
      expect(r.weight, FontWeight.w700, reason: '$r must be bold');
    }
  });

  test('no role can express a size', () {
    // The one-size rule is the change most likely to erode silently, so size
    // is not merely discouraged here -- it is inexpressible.
    for (final r in TextRole.values) {
      expect(r.style.fontSize, isNull,
          reason: 'TextRole must not carry a size; the theme supplies it');
    }
  });
}
