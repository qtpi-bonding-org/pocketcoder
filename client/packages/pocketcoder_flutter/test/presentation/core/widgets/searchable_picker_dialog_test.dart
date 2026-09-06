import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/searchable_picker_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

// A minimal test-only picker tile fixture -- exposes isSelected as a plain
// field for assertions, independent of whatever row widget production code
// happens to use.
class _PickerTile extends StatelessWidget {
  const _PickerTile(
      {required this.label, required this.isSelected, required this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap, child: TerminalText(label, role: TextRole.body));
}

Widget _tile(
  BuildContext context,
  String item, {
  required bool isSelected,
  required VoidCallback onTap,
}) =>
    _PickerTile(label: item, isSelected: isSelected, onTap: onTap);

Future<String?> _open(
  WidgetTester tester, {
  required List<String> items,
  String Function(String)? groupLabel,
  String? selected,
  int? maxUnfilteredResults,
}) {
  return showDialog<String>(
    context: tester.element(find.byType(Scaffold)),
    builder: (_) => SearchablePickerDialog<String>(
      title: 'PICK ONE',
      items: items,
      itemLabel: (s) => s,
      itemBuilder: _tile,
      groupLabel: groupLabel,
      selectedItem: selected,
      maxUnfilteredResults: maxUnfilteredResults,
      emptyLabel: 'NOTHING TO PICK',
      noMatchesLabel: 'NO MATCHES',
    ),
  );
}

void main() {
  testWidgets('filters items by substring match on itemLabel, case-insensitive',
      (tester) async {
    await tester.pumpWidget(_app(const SizedBox()));
    final future = _open(tester, items: ['ANTHROPIC', 'OPENAI', 'OPENROUTER']);
    await tester.pumpAndSettle();

    expect(find.text('ANTHROPIC'), findsOneWidget);
    expect(find.text('OPENAI'), findsOneWidget);
    expect(find.text('OPENROUTER'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'open');
    await tester.pumpAndSettle();

    expect(find.text('ANTHROPIC'), findsNothing);
    expect(find.text('OPENAI'), findsOneWidget);
    expect(find.text('OPENROUTER'), findsOneWidget);

    await tester.tap(find.text('OPENAI'));
    await tester.pumpAndSettle();

    expect(await future, 'OPENAI');
  });

  testWidgets('shows noMatchesLabel when the search query matches nothing',
      (tester) async {
    await tester.pumpWidget(_app(const SizedBox()));
    unawaited(_open(tester, items: ['ANTHROPIC']));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz-nonexistent');
    await tester.pumpAndSettle();

    expect(find.text('ANTHROPIC'), findsNothing);
    expect(find.text('NO MATCHES'), findsOneWidget);
  });

  testWidgets('shows emptyLabel when items is empty from the start',
      (tester) async {
    await tester.pumpWidget(_app(const SizedBox()));
    unawaited(_open(tester, items: const []));
    await tester.pumpAndSettle();

    expect(find.text('NOTHING TO PICK'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
      'groupLabel inserts a header before each group, sorted by group then '
      'item label', (tester) async {
    await tester.pumpWidget(_app(const SizedBox()));
    unawaited(_open(
      tester,
      items: ['ZEBRA-MODEL', 'APPLE-MODEL', 'MANGO-MODEL'],
      groupLabel: (item) =>
          item == 'APPLE-MODEL' ? 'FRUIT HARNESS' : 'OTHER HARNESS',
    ));
    await tester.pumpAndSettle();

    final headerFinder = find.text('FRUIT HARNESS');
    final otherHeaderFinder = find.text('OTHER HARNESS');
    expect(headerFinder, findsOneWidget);
    expect(otherHeaderFinder, findsOneWidget);

    // FRUIT HARNESS group (just APPLE-MODEL) must render above OTHER
    // HARNESS (MANGO-MODEL, ZEBRA-MODEL) -- confirm via widget vertical
    // position rather than list order, since ListView.builder is what's
    // under test.
    final fruitHeaderY = tester.getTopLeft(headerFinder).dy;
    final otherHeaderY = tester.getTopLeft(otherHeaderFinder).dy;
    expect(fruitHeaderY, lessThan(otherHeaderY));

    final mangoY = tester.getTopLeft(find.text('MANGO-MODEL')).dy;
    final zebraY = tester.getTopLeft(find.text('ZEBRA-MODEL')).dy;
    expect(mangoY, lessThan(zebraY));
  });

  testWidgets('marks the selectedItem tile as selected', (tester) async {
    await tester.pumpWidget(_app(const SizedBox()));
    unawaited(_open(tester, items: ['A', 'B'], selected: 'B'));
    await tester.pumpAndSettle();

    final aRow = tester.widget<_PickerTile>(
      find.ancestor(of: find.text('A'), matching: find.byType(_PickerTile)),
    );
    final bRow = tester.widget<_PickerTile>(
      find.ancestor(of: find.text('B'), matching: find.byType(_PickerTile)),
    );
    expect(aRow.isSelected, isFalse);
    expect(bRow.isSelected, isTrue);
  });

  testWidgets(
      'a custom matches predicate is used for filtering instead of the '
      'itemLabel substring default, without changing sort/display order',
      (tester) async {
    await tester.pumpWidget(_app(const SizedBox()));
    unawaited(showDialog<String>(
      context: tester.element(find.byType(Scaffold)),
      builder: (_) => SearchablePickerDialog<String>(
        title: 'PICK ONE',
        items: const ['ANTHROPIC|anthropic', 'OPENAI|openai-compat'],
        // Display/sort key is just the display name (before the '|') --
        // deliberately NOT the same string matches() searches over, to
        // prove the two are independent.
        itemLabel: (s) => s.split('|').first,
        matches: (s, query) => s.toLowerCase().contains(query.toLowerCase()),
        itemBuilder: (context, s, {required isSelected, required onTap}) =>
            _PickerTile(
          label: s.split('|').first,
          isSelected: isSelected,
          onTap: onTap,
        ),
        emptyLabel: 'NOTHING TO PICK',
        noMatchesLabel: 'NO MATCHES',
      ),
    ));
    await tester.pumpAndSettle();

    // "compat" only appears in the second half of OPENAI's raw string
    // (after the '|'), which itemLabel alone would never expose.
    await tester.enterText(find.byType(TextField), 'compat');
    await tester.pumpAndSettle();

    expect(find.text('ANTHROPIC'), findsNothing);
    expect(find.text('OPENAI'), findsOneWidget);
  });

  testWidgets(
      'maxUnfilteredResults caps the empty-query list to the first N sorted '
      'items', (tester) async {
    await tester.pumpWidget(_app(const SizedBox()));
    unawaited(_open(
      tester,
      items: ['ZEBRA', 'APPLE', 'MANGO', 'BANANA'],
      maxUnfilteredResults: 2,
    ));
    await tester.pumpAndSettle();

    expect(find.text('APPLE'), findsOneWidget);
    expect(find.text('BANANA'), findsOneWidget);
    expect(find.text('MANGO'), findsNothing);
    expect(find.text('ZEBRA'), findsNothing);
  });

  testWidgets(
      'maxUnfilteredResults does not limit results once a search query is '
      'entered', (tester) async {
    await tester.pumpWidget(_app(const SizedBox()));
    unawaited(_open(
      tester,
      items: ['ZEBRA', 'APPLE', 'MANGO', 'BANANA'],
      maxUnfilteredResults: 2,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'A');
    await tester.pumpAndSettle();

    expect(find.text('APPLE'), findsOneWidget);
    expect(find.text('BANANA'), findsOneWidget);
    expect(find.text('MANGO'), findsOneWidget);
    expect(find.text('ZEBRA'), findsOneWidget);
  });
}
