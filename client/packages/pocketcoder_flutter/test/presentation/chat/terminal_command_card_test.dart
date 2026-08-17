import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/terminal_command_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_status_glyph.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('keeps the spinner static when reduced motion is enabled',
      (tester) async {
    await tester.pumpWidget(_wrap(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: const TerminalStatusGlyph(status: TerminalStatus.running),
      ),
    ));
    expect(find.text('|'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('|'), findsOneWidget);
  });

  testWidgets('shows a running command without output', (tester) async {
    await tester.pumpWidget(_wrap(
      const TerminalCommandCard(
        command: 'flutter test',
        status: TerminalStatus.running,
        outputLabel: 'OUTPUT',
      ),
    ));

    expect(find.text(r'$ flutter test'), findsOneWidget);
    expect(find.byType(TerminalStatusGlyph), findsOneWidget);
    expect(find.text('OUTPUT'), findsNothing);
  });

  testWidgets('keeps output collapsed until the output row is tapped',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(
      const TerminalCommandCard(
        command: 'flutter test',
        status: TerminalStatus.success,
        outputLabel: 'OUTPUT',
        output: 'All tests passed!',
      ),
    ));

    expect(find.text('OUTPUT'), findsOneWidget);
    expect(find.text('All tests passed!'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == 'OUTPUT',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('OUTPUT'));
    await tester.pumpAndSettle();

    expect(find.text('All tests passed!'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('renders flush, with no bordered container', (tester) async {
    await tester.pumpWidget(_wrap(const TerminalCommandCard(
      command: 'ls -la',
      status: TerminalStatus.success,
      outputLabel: 'OUTPUT',
      output: 'a\nb',
    )));
    await tester.pumpAndSettle();

    expect(find.text(r'$ ls -la'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TerminalCommandCard),
        matching: find.byType(Container),
      ),
      findsNothing,
    );
  });

  testWidgets('expanded output flows inline without a nested scroll view',
      (tester) async {
    await tester.pumpWidget(_wrap(const TerminalCommandCard(
      command: 'ls -la',
      status: TerminalStatus.success,
      outputLabel: 'OUTPUT',
      output: 'a\nb\nc',
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('OUTPUT'));
    await tester.pumpAndSettle();

    expect(find.text('a\nb\nc'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TerminalCommandCard),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
  });
}
