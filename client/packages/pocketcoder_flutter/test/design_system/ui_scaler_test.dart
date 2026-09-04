import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/screen_metrics.dart';
import 'package:pocketcoder_flutter/design_system/primitives/ui_scaler.dart';

void main() {
  test('a fixed width drives the scale factor without a BuildContext', () {
    UiScaler.instance.initFrom(const FixedScreenMetrics(393));
    expect(UiScaler.instance.scaleFactor, closeTo(1.0, 0.001));

    UiScaler.instance.initFrom(const FixedScreenMetrics(440));
    expect(UiScaler.instance.scaleFactor, closeTo(440 / 393, 0.001));
  });

  test('the clamps hold at both ends', () {
    UiScaler.instance.initFrom(const FixedScreenMetrics(200));
    expect(UiScaler.instance.scaleFactor, 0.85);

    UiScaler.instance.initFrom(const FixedScreenMetrics(2000));
    expect(UiScaler.instance.scaleFactor, 1.15);
  });

  test('re-initialising replaces the factor rather than accumulating', () {
    // The scaler is a global singleton whose state carries across pumpWidget
    // calls, so the golden harness re-initialises it per device. That must be
    // idempotent.
    UiScaler.instance.initFrom(const FixedScreenMetrics(440));
    final first = UiScaler.instance.scaleFactor;
    UiScaler.instance.initFrom(const FixedScreenMetrics(440));
    expect(UiScaler.instance.scaleFactor, first);
  });
}
