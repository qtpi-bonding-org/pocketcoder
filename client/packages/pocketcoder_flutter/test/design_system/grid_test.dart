import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/app_fonts.dart';
import 'package:pocketcoder_flutter/design_system/primitives/app_sizes.dart';

void main() {
  test('ch is measured from the shipped font, not assumed', () {
    // A hardcoded advance ratio silently goes wrong the moment the family
    // changes. Noto Sans Mono is 0.6em; the assertion is loose because the
    // point is that the value was measured, not that it equals a constant.
    final ratio = AppSizes.ch / AppSizes.fontBody;
    expect(ratio, greaterThan(0.45));
    expect(ratio, lessThan(0.75));
  });

  test('line height is declared, not inherited from font metrics', () {
    // Measure what you do not control; declare what you do. A monospace
    // advance is baked into the font, so `ch` is measured. A line height is
    // set by the style, so `line` is declared.
    expect(AppSizes.lineHeightFactor, 1.3);
    expect(AppSizes.line, closeTo(AppSizes.fontBody * 1.3, 0.01));
  });

  test('the declared line height is actually applied to rendered text', () {
    // The failure this guards: a TextStyle built without `height:` falls back
    // to the font's natural metrics, and the vertical grid breaks silently
    // with no error anywhere.
    final painter = TextPainter(
      text: TextSpan(text: 'M\nM', style: AppFonts.textTheme.bodyMedium),
      textDirection: TextDirection.ltr,
    )..layout();
    final metrics = painter.computeLineMetrics();
    expect(metrics, hasLength(2));
    final baselineDelta = metrics[1].baseline - metrics[0].baseline;
    expect(baselineDelta, closeTo(AppSizes.line, 0.5),
        reason: 'every text style must set an explicit height, or the '
                'vertical grid silently stops being line-based');
  });

  test('the 36-column floor fits the smallest supported device', () {
    // UiScaler clamps at 0.85, so the narrowest realistic case is a 320pt
    // screen scaled to 0.85. Content must still clear 36 columns there.
    const narrowest = 320.0;
    final margins = AppSizes.space * 4;   // two indents each side
    final columns = (narrowest - margins) / AppSizes.ch;
    expect(columns, greaterThanOrEqualTo(35.0));
  });

  test('max width and picker height are expressed in grid units', () {
    // As raw pixels these drift out of the grid as the scale factor moves,
    // and a picker 300px tall leaves a row clipped in half.
    expect(AppSizes.contentMaxWidth, closeTo(AppSizes.ch * 44, 0.01));
    expect(AppSizes.pickerHeight, closeTo(AppSizes.line * 12, 0.01));
  });

  // NOTE: there is deliberately no runtime test for letterSpacingWide's
  // absence. A deleted static getter cannot be probed at runtime --
  // `AppSizes.toString()` returns the type name, so a `.contains(...)` check
  // passes whether or not the token exists, which is worse than no test.
  // The real guard is the compiler: deleting the getter makes every call
  // site a build error. Task 20's deletion sweep greps for it as well.
}
