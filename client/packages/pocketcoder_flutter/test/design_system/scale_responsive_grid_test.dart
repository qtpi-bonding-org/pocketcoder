import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/screen_metrics.dart';
import 'package:pocketcoder_flutter/design_system/primitives/ui_scaler.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';

/// A size that stores its value at first access freezes the grid to whichever
/// scale happened to be active then. One process renders more than one scale:
/// the golden suite sweeps three devices, and the app re-scales on rotation,
/// resize and split-view.
void main() {
  test('the character grid follows the current scale', () {
    UiScaler.instance.initFrom(const FixedScreenMetrics(320));
    final narrowCh = AppSizes.ch;
    final narrowContent = AppSizes.contentMaxWidth;

    UiScaler.instance.initFrom(const FixedScreenMetrics(440));
    final wideCh = AppSizes.ch;
    final wideContent = AppSizes.contentMaxWidth;

    expect(wideCh, greaterThan(narrowCh),
        reason: 'ch is stuck at the first scale it was asked for: '
            'narrow=$narrowCh wide=$wideCh. Every ch-derived size, '
            'contentMaxWidth included, is then wrong for every later scale.');
    expect(wideContent, greaterThan(narrowContent),
        reason: 'contentMaxWidth follows ch: '
            'narrow=$narrowContent wide=$wideContent');

    // Going back down must move it back, not just forward once.
    UiScaler.instance.initFrom(const FixedScreenMetrics(320));
    expect(AppSizes.ch, closeTo(narrowCh, 0.0001));
  });

  test('AppSizes stores no scale-derived value', () {
    final src = File('lib/design_system/primitives/app_sizes.dart')
        .readAsLinesSync();
    final offenders = <String>[];
    for (var i = 0; i < src.length; i++) {
      if (src[i].trimLeft().startsWith('//')) continue;
      if (RegExp(r'static\s+final\b').hasMatch(src[i])) {
        offenders.add('app_sizes.dart:${i + 1}  ${src[i].trim()}');
      }
    }
    expect(offenders, isEmpty, reason: '''
Every AppSizes member is a getter so it re-derives from the live UiScaler
scale. A `static final` is evaluated once per isolate and then frozen, which
silently pins the whole grid to the first scale seen.
${offenders.join('\n')}
''');
  });
}
