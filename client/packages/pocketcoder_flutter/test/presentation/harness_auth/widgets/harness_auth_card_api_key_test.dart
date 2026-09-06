import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_provider.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/harness_auth/widgets/harness_auth_view.dart';

void main() {
  final harness = Harnesse(
    id: 'harness-1',
    name: 'Goose',
    cliId: 'goose',
    acpTransport: HarnesseAcpTransport.websocket,
    providerFanout: true,
  );
  final nonOauthEdges = [
    const HarnessProvider(
      id: 'edge-1',
      harness: 'harness-1',
      provider: 'provider-1',
      supportsOauth: false,
    ),
  ];

  Future<void> pumpCard(
    WidgetTester tester, {
    required List<HarnessProvider> edges,
    domain.Provider? configuredApiKeyProvider,
    VoidCallback? onUseApiKey,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HarnessAuthCard(
            harness: harness,
            harnessProviders: edges,
            status: null,
            configuredApiKeyProvider: configuredApiKeyProvider,
            codeController: TextEditingController(),
            isBusy: false,
            onStartAccount: (_) {},
            onUseApiKey: onUseApiKey ?? () {},
            onSubmit: (_) async {},
            onCancel: () {},
            onDisconnect: () {},
            onRefresh: () {},
            onOpenAuthorizationPage: (_) {},
            onCopyCode: (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets(
      'a harness with no oauth-capable provider offers ADD KEY instead of '
      'nothing', (tester) async {
    var tapped = false;
    await pumpCard(
      tester,
      edges: nonOauthEdges,
      onUseApiKey: () => tapped = true,
    );

    expect(find.text('<account login>'), findsNothing);
    expect(find.text('<add key>'), findsOneWidget);

    await tester.tap(find.text('<add key>'));
    expect(tapped, isTrue);
  });

  testWidgets(
      'a harness with an already-configured API key shows which provider '
      'it is using', (tester) async {
    await pumpCard(
      tester,
      edges: nonOauthEdges,
      configuredApiKeyProvider: const domain.Provider(
          id: 'provider-1', providerId: 'anthropic', name: 'Anthropic'),
    );

    expect(find.textContaining('Anthropic'), findsOneWidget);
    expect(find.text('<add key>'), findsOneWidget);
  });

  testWidgets(
      'a harness with an oauth-capable provider still shows ACCOUNT LOGIN, '
      'not ADD KEY', (tester) async {
    await pumpCard(
      tester,
      edges: const [
        HarnessProvider(
          id: 'edge-2',
          harness: 'harness-1',
          provider: 'provider-2',
          supportsOauth: true,
        ),
      ],
    );

    expect(find.text('<account login>'), findsOneWidget);
    expect(find.text('<add key>'), findsNothing);
  });
}
