import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/status_marker.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/service_line.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

void main() {
  testWidgets('prefix is dim, name is a value, detail is a label',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: ServiceLine(
              name: 'pocketbase', detail: '6d 4h', status: StatusMarker.ok)),
    ));
    expect(
        tester.widget<TerminalText>(find.widgetWithText(TerminalText, '*'))
            .role,
        TextRole.label);
    expect(
        tester
            .widget<TerminalText>(
                find.widgetWithText(TerminalText, 'pocketbase'))
            .role,
        TextRole.value);
    expect(
        tester
            .widget<TerminalText>(find.widgetWithText(TerminalText, '6d 4h'))
            .role,
        TextRole.label);
  });

  testWidgets('detail is optional', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: ServiceLine(name: 'goose', status: StatusMarker.attention)),
    ));
    expect(find.text('goose'), findsOneWidget);
  });
}
