import 'package:acp_dart/acp_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/agent/widgets/config_picker.dart';

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

  testWidgets(
      'all options render as their own chips, not a collapsed summary',
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
    expect(find.byType(ConfigOptionChip), findsNWidgets(3));
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

      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();

      expect(find.text('b'), findsOneWidget);
    });

    testWidgets(
        'shows only what follows the last "/" of the current model id, '
        'not the full harnessModelId', (tester) async {
      const config = {
        'options': [
          {'id': 'model', 'name': 'model', 'kind': 'select',
           'currentValue': 'anthropic/claude-haiku-4.5'},
        ],
      };
      await tester.pumpWidget(_wrap(ConfigPicker(
        config: config,
        onSetOption: (_) {},
        onSearchModels: () async => models,
      )));

      expect(find.text('claude-haiku-4.5'), findsOneWidget);
      expect(find.text('anthropic/claude-haiku-4.5'), findsNothing);
    });
  });

  testWidgets(
      'renders the model chip last regardless of its position in config, '
      'so the shorter options can share a line', (tester) async {
    const config = {
      'options': [
        {'id': 'provider', 'name': 'provider', 'kind': 'select',
         'currentValue': 'openrouter',
         'options': [{'value': 'openrouter', 'label': 'openrouter'}]},
        {'id': 'model', 'name': 'model', 'kind': 'select',
         'currentValue': 'anthropic/claude-haiku-4.5'},
        {'id': 'mode', 'name': 'mode', 'kind': 'select',
         'currentValue': 'approve',
         'options': [{'value': 'approve', 'label': 'approve'}]},
      ],
    };
    await tester.pumpWidget(_wrap(ConfigPicker(
      config: config,
      onSetOption: (_) {},
      onSearchModels: () async => const [],
    )));

    final chips = tester
        .widgetList<ConfigOptionChip>(find.byType(ConfigOptionChip))
        .toList();
    expect(chips.map((c) => c.label), ['provider', 'mode', 'model']);
  });

  group('thinking effort truncation', () {
    testWidgets('a short value like "off" renders untruncated',
        (tester) async {
      const config = {
        'options': [
          {'id': 'thinking_effort', 'name': 'thinking effort', 'kind': 'select',
           'currentValue': 'off',
           'options': [{'value': 'off', 'label': 'off'}]},
        ],
      };
      await tester.pumpWidget(
        _wrap(ConfigPicker(config: config, onSetOption: (_) {})),
      );

      expect(find.text('off'), findsOneWidget);
    });

    testWidgets('an unusually long value gets ellipsized, not left to wrap',
        (tester) async {
      const config = {
        'options': [
          {'id': 'thinking_effort', 'name': 'thinking effort', 'kind': 'select',
           'currentValue': 'extremely-high-reasoning-effort',
           'options': [
             {'value': 'extremely-high-reasoning-effort',
              'label': 'extremely-high-reasoning-effort'},
           ]},
        ],
      };
      await tester.pumpWidget(
        _wrap(ConfigPicker(config: config, onSetOption: (_) {})),
      );

      // Text's `data` always carries the full string -- overflow/maxLines
      // control the *painted* result, not what's findable by text.
      final text = tester.widget<Text>(find.descendant(
        of: find.byType(ConfigOptionChip),
        matching: find.byType(Text),
      ).first);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.maxLines, 1);
    });
  });

  testWidgets('lays every chip out in a single Wrap, not one row each',
      (tester) async {
    const config = {
      'options': [
        {'id': 'provider', 'name': 'provider', 'kind': 'select',
         'currentValue': 'openrouter',
         'options': [{'value': 'openrouter', 'label': 'openrouter'}]},
        {'id': 'auto_approve', 'name': 'auto approve', 'kind': 'boolean',
         'currentValue': false},
      ],
    };
    await tester.pumpWidget(
      _wrap(ConfigPicker(config: config, onSetOption: (_) {})),
    );

    expect(find.byType(Wrap), findsOneWidget);
    expect(
        tester
            .widgetList<ConfigOptionChip>(find.byType(ConfigOptionChip))
            .length,
        2);
  });

  testWidgets('a boolean chip toggles in one tap', (tester) async {
    SetSessionConfigOptionRequest? submitted;
    const config = {
      'options': [
        {'id': 'auto_approve', 'name': 'auto approve', 'kind': 'boolean',
         'currentValue': false},
      ],
    };
    await tester.pumpWidget(_wrap(ConfigPicker(
      config: config,
      onSetOption: (req) => submitted = req,
    )));

    expect(find.text('off'), findsOneWidget);
    await tester.tap(find.text('off'));

    expect(submitted?.configId, 'auto_approve');
    expect(submitted?.value, 'true');
  });

  testWidgets(
      'chips show only the value, not the label -- the label survives as a '
      'Semantics announcement instead', (tester) async {
    await tester.pumpWidget(
      _wrap(ConfigPicker(config: _config, onSetOption: (_) {})),
    );

    expect(find.text('model'), findsNothing);
    expect(find.text('a'), findsOneWidget);
    expect(
        tester.getSemantics(find.byType(ConfigOptionChip)).label,
        contains('model'));
  });
}
