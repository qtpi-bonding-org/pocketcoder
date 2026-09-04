import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

void main() {
  testWidgets('role supplies color and weight, theme supplies size',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: TerminalText('uptime', role: TextRole.label)),
    ));
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.style!.color, TextRole.label.color);
    expect(text.style!.fontWeight, TextRole.label.weight);
    expect(text.style!.fontSize, isNull,
        reason: 'size comes from the theme, never from the widget');
  });

  testWidgets('value role is bright and bold', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: TerminalText('stable#47', role: TextRole.value)),
    ));
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.style!.color, TextRole.value.color);
    expect(text.style!.fontWeight, FontWeight.w700);
  });
}
