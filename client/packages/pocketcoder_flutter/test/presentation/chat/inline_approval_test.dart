import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/inline_approval.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

void main() {
  testWidgets('no tint, no border -- it lives in the stream', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: InlineApproval(
        toolLabel: 'a command',
        command: 'rm -rf /workspace/build',
        requestId: 'req_8f21c',
        options: [],
      )),
    ));
    for (final c in tester.widgetList<Container>(find.byType(Container))) {
      final d = c.decoration;
      if (d is BoxDecoration) {
        expect(d.border, isNull, reason: 'spec section 8: the box is removed');
        expect(d.color, anyOf(isNull, Colors.transparent));
      }
    }
  });

  testWidgets('the command is bright, never red', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: InlineApproval(
        toolLabel: 'a command',
        command: 'rm -rf /workspace/build',
        requestId: 'req_8f21c',
        options: [],
      )),
    ));
    final cmd = tester.widget<TerminalText>(
        find.widgetWithText(TerminalText, 'a command: rm -rf /workspace/build'));
    expect(cmd.role, TextRole.value,
        reason: 'colouring it red would be deciding it is destructive, '
            'which is interpretation (spec section 2b)');
  });

  testWidgets('the request id stays out of the transcript', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: InlineApproval(
        toolLabel: 'shell',
        command: 'ls',
        requestId: '0e013a72-717a-42da-a3be-3bf84a600a41',
        options: [],
      )),
    ));
    expect(find.textContaining('0e013a72'), findsNothing);
  });

  testWidgets('no description line when the harness supplied none',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: InlineApproval(
        toolLabel: 'a command',
        command: 'ls',
        requestId: 'req_1',
        options: [],
      )),
    ));
    expect(find.byKey(const ValueKey('inline-approval-description')),
        findsNothing);
  });
}
