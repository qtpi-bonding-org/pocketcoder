import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/status_marker.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/status_marker_view.dart';

void main() {
  testWidgets('brackets are dim and only the word takes the status colour',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StatusMarkerView(marker: StatusMarker.ok)),
    ));
    expect(
        tester.widget<Text>(find.text('[')).style!.color, TextRole.label.color);
    expect(
        tester.widget<Text>(find.text(']')).style!.color, TextRole.label.color);
    expect(
        tester.widget<Text>(find.text('ok')).style!.color, TextRole.ok.color);
  });

  testWidgets('failure and warning share the !! word, differ in colour',
      (tester) async {
    for (final (marker, role) in [
      (StatusMarker.attention, TextRole.warn),
      (StatusMarker.failed, TextRole.fail),
    ]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StatusMarkerView(marker: marker)),
      ));
      expect(tester.widget<Text>(find.text('!!')).style!.color, role.color);
    }
  });

  testWidgets('the tick and cross are gone', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StatusMarkerView(marker: StatusMarker.ok)),
    ));
    expect(find.textContaining('✓'), findsNothing);
    expect(find.textContaining('×'), findsNothing);
  });
}
