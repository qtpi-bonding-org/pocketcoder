import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/send_action.dart';

void main() {
  testWidgets('tapping SendAction invokes onSend', (tester) async {
    var sent = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SendAction(onSend: () => sent = true),
      ),
    ));

    await tester.tap(find.byType(SendAction));
    await tester.pump();

    expect(sent, isTrue);
  });

  testWidgets('tapping a disabled SendAction does not invoke onSend',
      (tester) async {
    var sent = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SendAction(onSend: () => sent = true, enabled: false),
      ),
    ));

    await tester.tap(find.byType(SendAction));
    await tester.pump();

    expect(sent, isFalse);
  });

  testWidgets('renders the return glyph, not a worded label', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SendAction(onSend: () {}),
      ),
    ));

    expect(find.text('↵'), findsOneWidget);
    expect(find.text('SEND'), findsNothing);
    expect(find.text('<send>'), findsNothing);
  });
}
