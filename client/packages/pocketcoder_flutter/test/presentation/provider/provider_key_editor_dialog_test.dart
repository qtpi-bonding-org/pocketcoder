import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/presentation/provider/widgets/provider_widgets.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

const _anthropic = domain.Provider(
  id: 'p1',
  providerId: 'anthropic',
  name: 'Anthropic',
);

void main() {
  testWidgets(
      'selecting a provider and saving writes its record id and typed key',
      (tester) async {
    ProviderApiKey? saved;
    await tester.pumpWidget(_app(ProviderKeyEditorDialog(
      providerCatalog: const [_anthropic],
      onSave: (key) => saved = key,
    )));
    await tester.tap(find.byType(DetailRow));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anthropic'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'sk-test-key');
    await tester.tap(find.text('<save>'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.provider, 'p1');
    expect(saved!.apiKey, 'sk-test-key');
  });

  testWidgets('tapping SAVE with no target selected never calls onSave',
      (tester) async {
    var called = false;
    await tester.pumpWidget(_app(ProviderKeyEditorDialog(
      providerCatalog: const [],
      onSave: (_) => called = true,
    )));
    await tester.enterText(find.byType(TextField), 'sk-orphan-key');
    await tester.tap(find.text('<save>'));
    expect(called, isFalse);
  });

  testWidgets('tapping SAVE with an empty key value never calls onSave',
      (tester) async {
    var called = false;
    await tester.pumpWidget(_app(ProviderKeyEditorDialog(
      providerCatalog: const [_anthropic],
      onSave: (_) => called = true,
    )));
    await tester.tap(find.byType(DetailRow));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anthropic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('<save>'));
    expect(called, isFalse);
  });

  testWidgets(
      'editing an existing key starts blank and preserves its key when unchanged',
      (tester) async {
    ProviderApiKey? saved;
    await tester.pumpWidget(_app(ProviderKeyEditorDialog(
      providerCatalog: const [_anthropic],
      existing: const ProviderApiKey(
        id: 'pk1',
        owner: 'u1',
        provider: 'p1',
        apiKey: '',
      ),
      onSave: (key) => saved = key,
    )));
    expect(find.text('Anthropic'), findsOneWidget);
    expect(find.text('Leave blank to keep the existing key'), findsOneWidget);
    await tester.tap(find.text('<save>'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.id, 'pk1');
    expect(saved!.owner, 'u1');
    expect(saved!.provider, 'p1');
    expect(saved!.apiKey, isEmpty);
  });
}
