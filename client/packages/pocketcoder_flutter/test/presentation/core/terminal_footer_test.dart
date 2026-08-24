import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';

void main() {
  testWidgets('an active action renders inverted: filled bg, dark text',
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

    final text = tester.widget<Text>(find.text('CHAT'));
    expect(text.style?.color, Colors.black);
  });

  testWidgets('an inactive action renders its own color on a transparent bg',
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

    final text = tester.widget<Text>(find.text('CHAT'));
    expect(text.style?.color, isNot(Colors.black));
  });
}
