import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/agent/widgets/mode_switcher.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('ModeSwitcher renders as a single dropdown, not a chip row',
      (tester) async {
    String? selected;
    await tester.pumpWidget(_wrap(
      ModeSwitcher(
        modes: const {
          'currentModeId': 'agent',
          'availableModes': [
            {'id': 'read-only', 'name': 'Read-Only'},
            {'id': 'agent', 'name': 'Agent'},
            {'id': 'full', 'name': 'Agent (Full Access)'},
          ],
        },
        onSelectMode: (id) => selected = id,
      ),
    ));

    expect(find.text('Agent'), findsOneWidget);
    expect(find.text('Read-Only'), findsNothing);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Read-Only'), findsOneWidget);

    await tester.tap(find.text('Read-Only').last);
    await tester.pumpAndSettle();
    expect(selected, 'read-only');
  });

  testWidgets('a mode with no id is skipped, never offered as a menu item',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ModeSwitcher(
        modes: const {
          'currentModeId': 'agent',
          'availableModes': [
            {'name': 'No Id Mode'},
            {'id': 'agent', 'name': 'Agent'},
          ],
        },
        onSelectMode: (_) {},
      ),
    ));

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('NO ID MODE'), findsNothing);
    expect(find.text('Agent'), findsWidgets);
  });
}
