import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_conversation.dart';

void main() {
  testWidgets('renders a terminal prompt suggestion without editable input',
      (tester) async {
    var selected = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: TerminalPromptSuggestion(
            label: 'What is a container?',
            onSelected: () => selected = true,
          ),
        ),
      ),
    );

    expect(find.text('> WHAT IS A CONTAINER?'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('> WHAT IS A CONTAINER?'));
    expect(selected, isTrue);
  });

  testWidgets('renders a prepared user turn as a read-only terminal line',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: TerminalConversationTurn(
            speaker: TerminalConversationSpeaker.user,
            message: 'Why does Docker need rules?',
          ),
        ),
      ),
    );

    expect(find.text('\$ Why does Docker need rules?'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
