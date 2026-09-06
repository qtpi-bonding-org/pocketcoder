import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_progress_bar.dart';

void main() {
  test('fills proportionally', () {
    expect(const TerminalProgressBar(step: 0, total: 8, width: 8).filled, 0);
    expect(const TerminalProgressBar(step: 4, total: 8, width: 8).filled, 4);
    expect(const TerminalProgressBar(step: 8, total: 8, width: 8).filled, 8);
  });

  test('an unfinished phase never renders a full bar', () {
    // 14/15 rounds to 8/8 cells, which would claim the phase is done.
    expect(const TerminalProgressBar(step: 14, total: 15, width: 8).filled, 7);
  });

  test('a total that has not arrived yet renders empty, not a crash', () {
    expect(const TerminalProgressBar(step: 3, total: 0, width: 8).filled, 0);
  });

  test('a step outside the range is clamped', () {
    expect(const TerminalProgressBar(step: -2, total: 8, width: 8).filled, 0);
    expect(const TerminalProgressBar(step: 99, total: 8, width: 8).filled, 8);
  });

  testWidgets('renders filled then empty cells at the requested width',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: TerminalProgressBar(step: 3, total: 6, width: 8),
      ),
    ));
    expect(find.text('████░░░░'), findsOneWidget);
  });
}
