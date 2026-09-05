import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/agent/widgets/config_picker.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

const _config = {
  'options': [
    {'id': 'model', 'name': 'model', 'kind': 'select', 'currentValue': 'a',
     'options': [{'value': 'a', 'label': 'a'}, {'value': 'b', 'label': 'b'}]},
  ],
};

void main() {
  testWidgets('the disclosure glyph states what the tap will do',
      (tester) async {
    await tester.pumpWidget(
      _wrap(ConfigPicker(config: _config, onSetOption: (_) {})),
    );

    Finder header(String glyph) => find.descendant(
          of: find.byType(DetailRow).first,
          matching: find.text(glyph),
        );

    // Collapsed: tapping reveals, so the row offers "expand".
    expect(header(RowAffordance.expand.glyph), findsOneWidget);
    expect(header(RowAffordance.collapse.glyph), findsNothing);

    await tester.tap(header(RowAffordance.expand.glyph));
    await tester.pump();

    // Expanded: tapping hides, so the row offers "collapse".
    expect(header(RowAffordance.collapse.glyph), findsOneWidget);
    expect(header(RowAffordance.expand.glyph), findsNothing);
  });

  testWidgets('collapsed, it is one row summarising the active session',
      (tester) async {
    const config = {
      'options': [
        {'id': 'provider', 'name': 'provider', 'kind': 'select',
         'currentValue': 'openrouter',
         'options': [{'value': 'openrouter', 'label': 'openrouter'}]},
        {'id': 'model', 'name': 'model', 'kind': 'select',
         'currentValue': 'aion-2.0',
         'options': [{'value': 'aion-2.0', 'label': 'aion-2.0'}]},
        {'id': 'mode', 'name': 'mode', 'kind': 'select',
         'currentValue': 'approve',
         'options': [{'value': 'approve', 'label': 'approve'}]},
      ],
    };
    await tester.pumpWidget(
      _wrap(ConfigPicker(config: config, onSetOption: (_) {})),
    );

    expect(find.text('openrouter · aion-2.0 · approve'), findsOneWidget);
    // The individual rows stay hidden until asked for.
    expect(find.byType(DetailRow), findsOneWidget);
  });
}
