import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(theme: AppTheme.darkTheme, home: child);

  testWidgets('scaffold renders body without a title bar', (tester) async {
    await tester.pumpWidget(wrap(const TerminalScaffold(
      body: Text('BODY'),
    )));

    expect(find.text('MY TITLE'), findsNothing);
    expect(find.text('BODY'), findsOneWidget);
  });

  testWidgets('has no floatingActionButton constructor parameter',
      (tester) async {
    await tester.pumpWidget(wrap(const TerminalScaffold(
      body: Text('BODY'),
    )));
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.floatingActionButton, isNull);
  });
}
