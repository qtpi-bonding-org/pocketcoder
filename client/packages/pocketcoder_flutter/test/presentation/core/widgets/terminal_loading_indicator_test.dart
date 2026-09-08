import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_spinner.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.terminalTheme,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('always renders a spinner -- there is no status parameter',
      (tester) async {
    await tester.pumpWidget(_wrap(const TerminalLoadingIndicator()));
    expect(find.byType(TerminalSpinner), findsOneWidget);
  });

  testWidgets('renders a label as plain text below the spinner when given',
      (tester) async {
    await tester
        .pumpWidget(_wrap(const TerminalLoadingIndicator(label: 'connecting')));
    expect(find.byType(TerminalSpinner), findsOneWidget);
    expect(find.text('connecting'), findsOneWidget);
    expect(find.text('[ CONNECTING ]'), findsNothing);
  });

  testWidgets('renders no label line when label is omitted', (tester) async {
    await tester.pumpWidget(_wrap(const TerminalLoadingIndicator()));
    expect(find.byType(Text), findsNothing);
  });
}
