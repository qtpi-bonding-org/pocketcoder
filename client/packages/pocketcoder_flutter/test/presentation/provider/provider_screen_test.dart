import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/provider/provider_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';
import 'package:pocketcoder_flutter/presentation/provider/adapters/provider_adapter.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  testWidgets('renders harness model tiles as BiosRows', (tester) async {
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

    expect(find.byType(BiosRow), findsOneWidget);
    expect(find.text('CLAUDE'), findsOneWidget);
    expect(find.text('SONNET'), findsOneWidget);
  });

  testWidgets(
      'a multi-provider-harness key shows its catalog display name, not the raw provider id',
      (tester) async {
    // provider="openai-compat-xyz" here is a models.dev catalog id (what
    // Goose/OpenCode keys are scoped by), not a harness cliId -- it won't
    // match any entry in `harnesses`, only in `providerCatalog`. Its
    // catalog display name deliberately differs from the id so this test
    // actually distinguishes "shows the catalog name" from "shows the id
    // uppercased" -- before the fix, this rendered "OPENAI-COMPAT-XYZ".
    await tester.pumpWidget(_app(ProviderView(
      state: ProviderState(
        providerKeys: const [
          ProviderKey(id: 'pk1', user: 'u1', provider: 'openai-compat-xyz'),
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

    expect(find.text('TOTALLY DIFFERENT DISPLAY NAME'), findsOneWidget);
    expect(find.text('OPENAI-COMPAT-XYZ'), findsNothing);
  });
}
