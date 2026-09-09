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

  testWidgets('typing without a trailing newline does not submit',
      (tester) async {
    final controller = TextEditingController();
    var submitted = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TerminalInput(
          controller: controller,
          onSubmitted: () => submitted = true,
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), '% deploy');
    await tester.pump();

    expect(submitted, isFalse);
    expect(controller.text, 'deploy');
  });

  testWidgets('a newline in the middle of the content does not submit',
      (tester) async {
    final controller = TextEditingController();
    var submitted = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TerminalInput(
          controller: controller,
          onSubmitted: () => submitted = true,
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), '% a\nb');
    await tester.pump();

    expect(submitted, isFalse);
    expect(controller.text, 'a\nb');
  });
}
