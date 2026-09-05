import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/agent/widgets/config_picker.dart';

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

    // Scoped to the header's own InkWell: an expanded select row is a
    // DetailRow carrying its own expand glyph, and matching the whole tree
    // would count that too.
    Finder header(String glyph) => find.descendant(
          of: find.byType(InkWell),
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
}
