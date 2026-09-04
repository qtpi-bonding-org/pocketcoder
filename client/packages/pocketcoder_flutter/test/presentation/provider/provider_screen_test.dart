import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/provider/provider_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/provider/adapters/provider_adapter.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  testWidgets(
      'harness model catalog is grouped into a collapsed-by-default '
      'section per harness -- model tiles only appear once expanded',
      (tester) async {
    await tester.pumpWidget(_app(ProviderView(
      state: ProviderState(
        harnesses: [
          const Harnesse(
            id: 'h1',
            name: 'Claude',
            cliId: 'claude',
            acpTransport: HarnesseAcpTransport.http,
          ),
        ],
        models: [
          const Model(
            id: 'm1',
            name: 'sonnet',
            displayName: 'Sonnet',
            provider: 'anthropic',
          ),
        ],
        harnessModels: [
          const HarnessModel(
            id: 'hm1',
            harness: 'h1',
            model: 'm1',
            harnessModelId: 'hm-1',
            isDefault: true,
          ),
        ],
      ),
      onDelete: (_) async {},
      onSave: (_) async {},
    )));

    // Collapsed by default: the harness section header is visible, but its
    // model tile is not built yet.
    expect(find.text('Claude'), findsOneWidget);
    expect(find.text('Sonnet'), findsNothing);

    await tester.tap(find.text('Claude'));
    await tester.pumpAndSettle();

    expect(find.text('Sonnet'), findsOneWidget);
  });

  testWidgets(
      'a harness with more than 50 models shows a "browse all" button '
      'instead of building every tile inline -- proves the section is '
      'genuinely lazy for a large catalog, not just visually collapsed',
      (tester) async {
    final manyModels = List.generate(
      51,
      (i) => HarnessModel(
        id: 'hm-$i',
        harness: 'h1',
        model: 'm1',
        harnessModelId: 'model-$i',
      ),
    );

    await tester.pumpWidget(_app(ProviderView(
      state: ProviderState(
        harnesses: [
          const Harnesse(
            id: 'h1',
            name: 'Claude',
            cliId: 'claude',
            acpTransport: HarnesseAcpTransport.http,
          ),
        ],
        harnessModels: manyModels,
      ),
      onDelete: (_) async {},
      onSave: (_) async {},
    )));

    await tester.tap(find.text('Claude'));
    await tester.pumpAndSettle();

    expect(find.text('model-0'), findsNothing);
    expect(find.text('model-50'), findsNothing);
    expect(find.text('<BROWSE ALL 51 MODELS>'), findsOneWidget);

    await tester.tap(find.text('<BROWSE ALL 51 MODELS>'));
    await tester.pumpAndSettle();

    expect(find.text('model-0'), findsOneWidget);
  });

  testWidgets(
      'a multi-provider-harness key shows its catalog display name, not the raw provider id',
      (tester) async {
    // ProviderApiKey.provider is always a pc_providers RECORD id (never a
    // provider_id string) -- 'p1' here matches providerCatalog[0].id, not
    // its providerId. Its catalog display name deliberately differs from
    // both so this test actually distinguishes "shows the catalog name"
    // from "shows the id/providerId uppercased" -- before the fix, this
    // rendered "OPENAI-COMPAT-XYZ".
    await tester.pumpWidget(_app(ProviderView(
      state: ProviderState(
        providerAPIKeys: const [
          ProviderApiKey(
            id: 'pk1',
            owner: 'u1',
            provider: 'p1',
            apiKey: 'secret',
          ),
        ],
        providerCatalog: const [
          domain.Provider(
            id: 'p1',
            providerId: 'openai-compat-xyz',
            name: 'Totally Different Display Name',
            apiKeyEnv: 'SOME_API_KEY',
          ),
        ],
      ),
      onDelete: (_) async {},
      onSave: (_) async {},
    )));

    expect(find.text('Totally Different Display Name'), findsOneWidget);
    expect(find.text('OPENAI-COMPAT-XYZ'), findsNothing);
  });
}
