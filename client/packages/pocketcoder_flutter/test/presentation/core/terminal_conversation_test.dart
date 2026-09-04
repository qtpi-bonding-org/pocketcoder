import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/poco.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/poco_bubble.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_conversation.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/typewriter_text.dart';

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

    expect(find.text('> What is a container?'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('> What is a container?'));
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

  testWidgets('typewriter completes within its configured character timing',
      (tester) async {
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: TypewriterText(
            text: '12345',
            speed: const Duration(milliseconds: 10),
            onComplete: () => completed = true,
          ),
        ),
      ),
    );

    // The typewriter samples on the 16 ms frame cadence, so allow the first
    // frame after the nominal five-character duration.
    await tester.pump(const Duration(milliseconds: 80));

    expect(completed, isTrue);
  });

  testWidgets('Poco bubble keeps its width while text grows vertically',
      (tester) async {
    final message = List.filled(
      40,
      'ONE TWO THREE FOUR FIVE SIX SEVEN EIGHT NINE TEN',
    ).join(' ');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 180,
              child: PocoBubble(
                posture: PocoPosture.armored,
                message: message,
                pocoSize: 16,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 16));
    final initialSize = tester.getSize(find.byType(PocoBubble));

    for (var frame = 0; frame < 10; frame += 1) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.getSize(find.byType(PocoBubble)).width,
        initialSize.width,
      );
    }

    final finalSize = tester.getSize(find.byType(PocoBubble));

    expect(finalSize.height, greaterThan(initialSize.height));
  });

  testWidgets('left-aligns a Poco conversation frame in its available content',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: const TerminalConversationTurn(
              speaker: TerminalConversationSpeaker.poco,
              message: 'Centered message',
            ),
          ),
        ),
      ),
    );

    final bubble = tester.getRect(find.byType(PocoBubble));
    expect(bubble.left, AppSizes.space);
  });

  testWidgets(
      'a user turn renders as a full-bleed phosphor fill with black text',
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

    final text = tester.widget<Text>(
      find.text('\$ Why does Docker need rules?'),
    );
    expect(text.style?.color, Colors.black);

    final frame = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(TerminalConversationFrame),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = frame.decoration as BoxDecoration;
    expect(decoration.color, isNot(anyOf(isNull, Colors.transparent)));
  });

  testWidgets('a poco turn is never inverted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: TerminalConversationTurn(
            speaker: TerminalConversationSpeaker.poco,
            message: 'hello',
            showPocoFace: false,
          ),
        ),
      ),
    );

    final frame = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(TerminalConversationFrame),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = frame.decoration as BoxDecoration?;
    expect(decoration?.color, anyOf(isNull, Colors.transparent));
  });
}
