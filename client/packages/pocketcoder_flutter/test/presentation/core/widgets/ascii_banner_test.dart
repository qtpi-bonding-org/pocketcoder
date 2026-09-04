import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ascii_art.dart';

void main() {
  test('every pillar has a banner and every banner fits 36 columns', () {
    for (final pillar in NavPillar.values) {
      final banner = AppAscii.bannerFor(pillar);
      expect(banner, isNotEmpty, reason: 'no banner for $pillar');
      for (final line in banner.split('\n')) {
        expect(line.length, lessThanOrEqualTo(36),
            reason: '$pillar banner exceeds the 36-column floor: '
                '${line.length} columns');
      }
    }
  });

  test('the boot banner also fits', () {
    for (final line in AppAscii.bootBanner.split('\n')) {
      expect(line.length, lessThanOrEqualTo(36));
    }
  });
}
