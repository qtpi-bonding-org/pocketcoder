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

  testWidgets('the armor takes the same colour as the face', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: PocoBubble(
              message: 'hmm',
              mood: PocoMood.suspicious,
              posture: PocoPosture.fortified)),
    ));
    final face = tester.widget<Text>(find.byKey(const ValueKey('poco-face')));
    final frame = tester.widget<Text>(find.byKey(const ValueKey('poco-frame')));
    expect(frame.style!.color, face.style!.color,
        reason: 'a frame in a different colour reads as two objects');
  });

  test('no expression maps to red', () {
    for (final mood in PocoMood.values) {
      expect(mood.color, isNot(AppPalette.red),
          reason: 'poco is never red -- he is neither destruction nor failure');
    }
  });
}
