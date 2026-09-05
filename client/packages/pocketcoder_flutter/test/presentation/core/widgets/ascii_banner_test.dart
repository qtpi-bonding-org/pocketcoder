import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_art.dart';

void main() {
  test('every pillar has a banner', () {
    for (final pillar in NavPillar.values) {
      expect(AppAscii.bannerFor(pillar), isNotEmpty,
          reason: 'no banner for $pillar');
    }
  });

  test('all four banners are the same width', () {
    // AsciiLogo renders art inside a FittedBox(scaleDown), which scales each
    // banner independently. Equal widths mean one shared scale factor, so the
    // letterforms stay the same size as the user moves between nav tabs.
    // Art is exempt from the 36-column text floor -- it scales rather than
    // wrapping or truncating -- so width is only a consistency question.
    final widths = {
      for (final pillar in NavPillar.values)
        pillar: AppAscii.bannerFor(pillar)
            .split('\n')
            .map((l) => l.length)
            .reduce((a, b) => a > b ? a : b),
    };
    expect(widths.values.toSet(), hasLength(1),
        reason: 'banners must share one width or they render at different '
            'sizes per tab. Pad the narrower ones with trailing spaces: '
            '$widths');
  });

  test('each banner is internally rectangular', () {
    for (final pillar in NavPillar.values) {
      final lines = AppAscii.bannerFor(pillar).split('\n');
      expect(lines.map((l) => l.length).toSet(), hasLength(1),
          reason: '$pillar has ragged lines; FittedBox fits the widest one, '
              'so short lines shift the art off-centre');
    }
  });
}
