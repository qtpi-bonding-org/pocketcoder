import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_input.dart';

void main() {
  testWidgets('TerminalInput never renders a SEND button', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TerminalInput(
          controller: TextEditingController(),
          onSubmitted: () {},
        ),
      ),
    ));

    expect(find.text('SEND'), findsNothing);
  });

  testWidgets('return/enter still submits', (tester) async {
    var submitted = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TerminalInput(
          controller: TextEditingController(),
          onSubmitted: () => submitted = true,
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), 'hi');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submitted, isTrue);
  });
}
