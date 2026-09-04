import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';

void main() {
  testWidgets('an active action renders inverted: filled bg in its role color',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: TerminalFooter(
            actions: [
              TerminalAction(label: 'chat', onTap: () {}, isActive: true),
            ],
          ),
        ),
      ),
    );

    expect(find.text('<chat>'), findsOneWidget);
    final container = tester.widget<Container>(
      find
          .descendant(
              of: find.byType(GestureDetector),
              matching: find.byType(Container))
          .first,
    );
    expect(container.color, ActionKind.neutral.role.color);
  });

  testWidgets('an inactive action renders on a transparent background',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: TerminalFooter(
            actions: [
              TerminalAction(label: 'chat', onTap: () {}),
            ],
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find
          .descendant(
              of: find.byType(GestureDetector),
              matching: find.byType(Container))
          .first,
    );
    expect(container.color, Colors.transparent);
  });

  testWidgets('a primary-kind action renders in the primary role color',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: TerminalFooter(
            actions: [
              TerminalAction(
                  label: 'connect', onTap: () {}, kind: ActionKind.primary),
            ],
          ),
        ),
      ),
    );

    expect(find.text('<connect>'), findsOneWidget);
    final text = tester.widget<Text>(find.text('<connect>'));
    expect(text.style?.color, ActionKind.primary.role.color);

    final container = tester.widget<Container>(
      find
          .descendant(
              of: find.byType(GestureDetector),
              matching: find.byType(Container))
          .first,
    );
    expect(container.color, Colors.transparent);
  });
}
