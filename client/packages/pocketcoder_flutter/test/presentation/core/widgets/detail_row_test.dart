import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';

void main() {
  testWidgets('label is sentence case in label role, value in value role',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: DetailRow(label: 'Uptime', value: '6d 4h')),
    ));
    // Lowercase, matching the rest of the redesign's angle-bracket/pillar/
    // section-header convention -- not 'UPTIME', not 'Uptime'.
    expect(find.text('uptime'), findsOneWidget);
    expect(tester.widget<Text>(find.text('uptime')).style!.color,
        TextRole.label.color);
    expect(tester.widget<Text>(find.text('6d 4h')).style!.color,
        TextRole.value.color);
  });

  testWidgets('navigate renders an arrow, expand renders a triangle',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Column(children: [
        DetailRow(
            label: 'Always allow',
            value: '3 rules',
            affordance: RowAffordance.navigate,
            onTap: () {}),
        DetailRow(
            label: 'Mode',
            value: 'ask every time',
            affordance: RowAffordance.expand,
            onTap: () {}),
      ])),
    ));
    expect(find.text('▸'), findsOneWidget); // navigate
    expect(find.text('▾'), findsOneWidget); // expand
    expect(find.textContaining('[>]'), findsNothing);
    expect(find.textContaining('[v]'), findsNothing);
  });

  testWidgets('toggle renders the word on/off, never a Switch', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: DetailRow.toggle(
              label: 'Approvals', value: true, onChanged: (_) {})),
    ));
    expect(find.text('on'), findsOneWidget);
    expect(find.byType(Switch), findsNothing,
        reason: 'a Material Switch cannot look like terminal output');
  });

  testWidgets('value stacks underneath rather than truncating when narrow',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: SizedBox(
              width: 200,
              child: DetailRow(
                label: 'Workspace',
                value: '/var/lib/pocketcoder/workspaces/default',
              ))),
    ));
    final value = tester
        .widget<Text>(find.text('/var/lib/pocketcoder/workspaces/default'));
    expect(value.overflow, isNot(TextOverflow.ellipsis),
        reason: 'spec section 3: never truncated, never scrolled sideways');
  });
}
