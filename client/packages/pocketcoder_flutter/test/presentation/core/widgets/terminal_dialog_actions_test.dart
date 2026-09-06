import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog_actions.dart';

void main() {
  testWidgets('labels are angle-bracketed and lowercase', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: TerminalDialogActions(actions: [
        TerminalActionSpec('restart', ActionKind.primary, () {}),
        TerminalActionSpec('cancel', ActionKind.refusal, () {}),
      ])),
    ));
    expect(find.text('<restart>'), findsOneWidget);
    expect(find.text('<cancel>'), findsOneWidget);
  });

  testWidgets('a destructive action is never first', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: TerminalDialogActions(actions: [
        TerminalActionSpec('delete', ActionKind.destructive, () {}),
        TerminalActionSpec('cancel', ActionKind.refusal, () {}),
      ])),
    ));
    // NOTE: widgetList returns build order, not painted position. That is
    // the right check ONLY because the implementation reorders the
    // List<TerminalActionSpec> before building the Wrap (see Step 3) -- so
    // build order IS the visual order here. If a future implementation ever
    // reorders visually instead (alignment tricks, Directionality), this
    // test silently stops guarding anything. Keep the sort in the list.
    final labels =
        tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
    expect(labels.first, isNot('<delete>'),
        reason: 'spec section 7: destructive never in first position');
  });
}
