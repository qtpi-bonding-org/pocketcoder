import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_header.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(theme: AppTheme.darkTheme, home: child);

  testWidgets('a null title renders no TerminalHeader', (tester) async {
    await tester.pumpWidget(wrap(const TerminalScaffold(
      title: null,
      body: Text('BODY'),
    )));

    expect(find.byType(TerminalHeader), findsNothing);
    expect(find.text('BODY'), findsOneWidget);
  });

  testWidgets('a non-null title still renders the header', (tester) async {
    await tester.pumpWidget(wrap(const TerminalScaffold(
      title: 'MY TITLE',
      body: Text('BODY'),
    )));

    expect(find.byType(TerminalHeader), findsOneWidget);
    expect(find.text('MY TITLE'), findsOneWidget);
  });

  testWidgets('has no floatingActionButton constructor parameter', (tester) async {
    await tester.pumpWidget(wrap(const TerminalScaffold(
      title: 'X',
      body: Text('BODY'),
    )));
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.floatingActionButton, isNull);
  });
}
