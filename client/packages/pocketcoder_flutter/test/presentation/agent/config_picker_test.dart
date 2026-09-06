import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/agent/widgets/config_picker.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
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
  testWidgets('each option is visible and directly tappable with no expand step first',
      (tester) async {
    await tester.pumpWidget(
      _wrap(ConfigPicker(config: _config, onSetOption: (_) {})),
    );

    // The option's own row is already on screen -- one tap opens its
    // picker, no collapse/expand row to tap through first.
    expect(find.text('a'), findsOneWidget);
    await tester.tap(find.text('a'));
    await tester.pumpAndSettle();

    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('opening a select option shows a search field', (tester) async {
    await tester.pumpWidget(
      _wrap(ConfigPicker(config: _config, onSetOption: (_) {})),
    );

    await tester.tap(find.text('a'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('all options render as their own rows, not a collapsed summary',
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

    expect(find.text('openrouter'), findsOneWidget);
    expect(find.text('aion-2.0'), findsOneWidget);
    expect(find.text('approve'), findsOneWidget);
    expect(find.byType(DetailRow), findsNWidgets(4));
    expect(find.text(RowAffordance.expand.glyph), findsNWidgets(3));
  });

  group('model row with onSearchModels provided', () {
    const models = [
      HarnessModel(
          id: 'hm-1',
          harness: 'harness-1',
          model: 'm-1',
          harnessModelId: 'anthropic/claude-sonnet-4.5'),
      HarnessModel(
          id: 'hm-2',
          harness: 'harness-1',
          model: 'm-2',
          harnessModelId: 'x-ai/grok-code-fast-1'),
    ];

    testWidgets(
        'tapping the model row opens a search dialog fed by onSearchModels, '
        'and picking a result submits its harnessModelId', (tester) async {
      Object? submitted;
      await tester.pumpWidget(_wrap(ConfigPicker(
        config: _config,
        onSetOption: (req) => submitted = req.value,
        onSearchModels: () async => models,
      )));

      await tester.tap(find.byType(DetailRow).first);
      await tester.pump();
      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();

      expect(find.text('anthropic/claude-sonnet-4.5'), findsOneWidget);
      expect(find.text('x-ai/grok-code-fast-1'), findsOneWidget);
      expect(find.text('b'), findsNothing);

      await tester.tap(find.text('x-ai/grok-code-fast-1'));
      await tester.pumpAndSettle();

      expect(submitted, 'x-ai/grok-code-fast-1');
    });

    testWidgets('without onSearchModels, the plain live-options list is used',
        (tester) async {
      await tester.pumpWidget(
        _wrap(ConfigPicker(config: _config, onSetOption: (_) {})),
      );

      await tester.tap(find.byType(DetailRow).first);
      await tester.pump();
      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();

      expect(find.text('b'), findsOneWidget);
    });
  });
}
