import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

void main() {
  testWidgets('never sets its own fontSize -- theme supplies size',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: TerminalText('uptime', role: TextRole.label)),
    ));
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.style!.fontSize, isNull);
  });
}
