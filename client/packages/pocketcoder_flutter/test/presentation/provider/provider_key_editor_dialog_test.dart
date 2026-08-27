import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';
import 'package:pocketcoder_flutter/presentation/provider/widgets/provider_widgets.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

const _claudeCode = Harnesse(
  id: 'h1',
  name: 'Claude Code',
  cliId: 'claude-code',
  acpTransport: HarnesseAcpTransport.stdio,
);

const _anthropicCatalogEntry = domain.Provider(
  id: 'p1',
  providerId: 'anthropic',
  name: 'Anthropic',
  apiKeyEnv: 'ANTHROPIC_API_KEY',
);

/// End-to-end wiring check for the actual "add an API key" flow: pick a
/// target in the picker dialog, type a key, tap SAVE, and verify the
/// resulting ProviderKey object -- not a real key, just confirming the
/// dialog's own state (_selectedTarget) actually reaches onSave with the
/// right `provider` value for both kinds of target.
void main() {
  testWidgets(
      'selecting a self-scoped harness and saving writes provider=cliId plus the typed key',
      (tester) async {
    ProviderKey? saved;
    await tester.pumpWidget(_app(ProviderKeyEditorDialog(
      harnesses: const [_claudeCode],
      providerCatalog: const [],
      onSave: (key) => saved = key,
    )));

    await tester.tap(find.byType(BiosRow));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CLAUDE CODE'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sk-test-claude-code-key');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.provider, 'claude-code');
    expect(saved!.envVars, {'API_KEY': 'sk-test-claude-code-key'});
  });

  testWidgets(
      'selecting a catalog provider (multi-provider harness key) writes provider=providerId, not a harness cliId',
      (tester) async {
    ProviderKey? saved;
    await tester.pumpWidget(_app(ProviderKeyEditorDialog(
      harnesses: const [],
      providerCatalog: const [_anthropicCatalogEntry],
      onSave: (key) => saved = key,
    )));

    await tester.tap(find.byType(BiosRow));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ANTHROPIC'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sk-test-anthropic-key');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.provider, 'anthropic');
    expect(saved!.envVars, {'API_KEY': 'sk-test-anthropic-key'});
  });

  testWidgets('tapping SAVE with no target selected never calls onSave',
      (tester) async {
    var called = false;
    await tester.pumpWidget(_app(ProviderKeyEditorDialog(
      harnesses: const [_claudeCode],
      providerCatalog: const [],
      onSave: (_) => called = true,
    )));

    await tester.enterText(find.byType(TextField), 'sk-orphan-key');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
  });

  testWidgets('tapping SAVE with an empty key value never calls onSave',
      (tester) async {
    var called = false;
    await tester.pumpWidget(_app(ProviderKeyEditorDialog(
      harnesses: const [_claudeCode],
      providerCatalog: const [],
      onSave: (_) => called = true,
    )));

    await tester.tap(find.byType(BiosRow));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CLAUDE CODE'));
    await tester.pumpAndSettle();

    // No text entered -- the field is left empty.
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
  });

  testWidgets(
      'editing an existing catalog-scoped key pre-selects its target and pre-fills the value',
      (tester) async {
    ProviderKey? saved;
    await tester.pumpWidget(_app(ProviderKeyEditorDialog(
      harnesses: const [],
      providerCatalog: const [_anthropicCatalogEntry],
      existing: const ProviderKey(
        id: 'pk1',
        user: 'u1',
        provider: 'anthropic',
        envVars: {'API_KEY': 'sk-existing-value'},
      ),
      onSave: (key) => saved = key,
    )));

    // The picker's BiosRow should already show the resolved target label.
    expect(find.text('ANTHROPIC'), findsOneWidget);

    // Change the value and save -- provider must stay pinned to the
    // already-selected target, and id/user must be carried over so this
    // is an update, not a new record.
    await tester.enterText(find.byType(TextField), 'sk-updated-value');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.id, 'pk1');
    expect(saved!.user, 'u1');
    expect(saved!.provider, 'anthropic');
    expect(saved!.envVars, {'API_KEY': 'sk-updated-value'});
  });
}
