import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_provider.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/harness_auth/widgets/harness_auth_view.dart';

void main() {
  final harness = Harnesse(
    id: 'harness-1',
    name: 'Codex',
    cliId: 'codex',
    acpTransport: HarnesseAcpTransport.stdio,
  );
  final edges = [
    const HarnessProvider(
      id: 'edge-1',
      harness: 'harness-1',
      provider: 'provider-1',
      supportsOauth: true,
    ),
  ];

  Future<void> pumpCard(
    WidgetTester tester,
    HarnessAuthChallenge challenge, {
    Uri? openedUri,
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
            status: HarnessAuthStatus(
              harness: 'harness-1',
              provider: 'provider-1',
              accountId: '',
              accountName: '',
              visibility: harnessAccountVisibilityPersonal,
              credentialMode: 'account',
              status: 'awaiting_input',
              challenge: challenge,
            ),
            codeController: TextEditingController(),
            isBusy: false,
            onStartAccount: (_) {},
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
      'a structured browser-destination challenge renders the shared '
      'connection view with no manual submit input', (tester) async {
    await pumpCard(
      tester,
      HarnessAuthChallenge.fromJson({
        'type': 'device-code',
        'text': 'legacy prose',
        'kind': 'device_code',
        'verificationUri': 'https://example.test/device',
        'userCode': 'ABCD-1234',
        'codeDestination': 'browser',
        'pollIntervalSeconds': 4,
      }),
    );

    expect(find.text('ABCD-1234'), findsOneWidget);
    expect(find.text('[OPEN AUTHORIZATION PAGE]'), findsOneWidget);
    expect(find.byType(TerminalTextField), findsNothing);
    expect(find.text('[SUBMIT]'), findsNothing);
  });

  testWidgets(
      'a legacy-only challenge (no structured fields) stays readable but '
      'offers no app-side code submission', (tester) async {
    await pumpCard(
      tester,
      const HarnessAuthChallenge(
        type: 'device',
        text: 'Visit the link and enter the code below.',
        target: 'https://example.test/device',
        details: 'ABCD-1234',
      ),
    );

    expect(find.textContaining('Visit the link'), findsOneWidget);
    expect(find.byType(TerminalTextField), findsNothing);
    expect(find.text('[SUBMIT]'), findsNothing);
  });
}
