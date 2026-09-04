import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/status_marker.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/service_line.dart';

void main() {
  testWidgets('prefix is dim, name is a value, detail is a label',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ServiceLine(
        name: 'pocketbase', detail: '6d 4h', status: StatusMarker.ok)),
    ));
    expect(tester.widget<Text>(find.text('*')).style!.color,
        TextRole.label.color);
    expect(tester.widget<Text>(find.text('pocketbase')).style!.color,
        TextRole.value.color);
    expect(tester.widget<Text>(find.text('6d 4h')).style!.color,
        TextRole.label.color);
  });

  testWidgets('detail is optional', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ServiceLine(
        name: 'goose', status: StatusMarker.attention)),
    ));
    expect(find.text('goose'), findsOneWidget);
  });
}