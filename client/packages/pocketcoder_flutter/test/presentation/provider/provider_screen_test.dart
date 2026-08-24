import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/provider/provider_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
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
}
