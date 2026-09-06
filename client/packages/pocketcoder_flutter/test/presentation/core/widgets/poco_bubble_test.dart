import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/app_palette.dart';
import 'package:pocketcoder_flutter/design_system/primitives/poco.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_bubble.dart';

void main() {
  testWidgets('poco speaks in the stream -- no border, no fill',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: PocoBubble(
              message: 'setting up your server', posture: PocoPosture.armored)),
    ));
    for (final c in tester.widgetList<Container>(find.byType(Container))) {
      final d = c.decoration;
      if (d is BoxDecoration) {
        expect(d.border, isNull, reason: 'spec section 12: no border');
        expect(d.color, anyOf(isNull, Colors.transparent));
      }
    }
  });

  test('no expression maps to red', () {
    for (final mood in PocoMood.values) {
      expect(mood.color, isNot(AppPalette.red),
          reason: 'poco is never red -- he is neither destruction nor failure');
    }
  });

  testWidgets('the face is never clipped: it gets its full frame height',
      (tester) async {
    // AsciiFace draws a three-line frame at height 1.0, so anything that
    // reserves less than 3x the font size cuts off the bottom border.
    const size = 24.0;
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PocoBubble(
          posture: PocoPosture.armored,
          message: 'hello',
          pocoSize: size,
        ),
      ),
    ));
    await tester.pump();

    final face = tester.getSize(find.byType(PocoFace));
    expect(face.height, greaterThanOrEqualTo(size * 3));
    expect(tester.takeException(), isNull);
  });
}
