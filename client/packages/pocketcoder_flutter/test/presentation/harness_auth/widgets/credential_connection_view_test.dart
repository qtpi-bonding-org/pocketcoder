import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/harness_auth/widgets/credential_connection_view.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );

  testWidgets('renders a browser device-code connection without app input',
      (tester) async {
    var submitted = false;
    await tester.pumpWidget(host(CredentialConnectionView(
      step: BrowserVerificationConnectionStep(
        verificationUri: Uri.parse('https://example.test'),
        codeDestination: HarnessAuthCodeDestination.browser,
        userCode: 'ABCD-1234',
      ),
      onOpenAuthorizationPage: () {},
      onCopyCode: (_) {},
      onSubmitCode: (_) => submitted = true,
      onCancel: () {},
      onRetry: () {},
    )));

    expect(find.text('ABCD-1234'), findsOneWidget);
    expect(find.text('[COPY]'), findsOneWidget);
    expect(find.text('[OPEN AUTHORIZATION PAGE]'), findsOneWidget);
    expect(find.textContaining('authorization page'), findsOneWidget);
    expect(find.byType(TerminalTextField), findsNothing);
    expect(find.text('[SUBMIT]'), findsNothing);
    await tester.tap(find.text('[COPY]'));
    await tester.pump();
    expect(submitted, isFalse);
  });

  testWidgets('shows an expiry notice only for an exact non-null timestamp',
      (tester) async {
    final expiresAt = DateTime.utc(2030, 4, 5, 12, 30);
    Widget view(DateTime? expiry) => host(CredentialConnectionView(
          step: BrowserVerificationConnectionStep(
            verificationUri: Uri.parse('https://example.test'),
            codeDestination: HarnessAuthCodeDestination.browser,
            userCode: 'EXPIRY-CODE',
            expiresAt: expiry,
          ),
          onOpenAuthorizationPage: () {},
          onCopyCode: (_) {},
          onSubmitCode: (_) {},
          onCancel: () {},
          onRetry: () {},
        ));

    await tester.pumpWidget(view(expiresAt));
    expect(find.textContaining('Expires at'), findsOneWidget);
    await tester.pumpWidget(view(null));
    expect(find.textContaining('Expires at'), findsNothing);
  });

  testWidgets('copy writes the exact device code to the platform clipboard',
      (tester) async {
    const channel = SystemChannels.platform;
    Map<String, dynamic>? message;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'Clipboard.setData') {
        message = Map<String, dynamic>.from(call.arguments as Map);
      }
      return null;
    });
    addTearDown(() async {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    await tester.pumpWidget(host(CredentialConnectionView(
      step: BrowserVerificationConnectionStep(
        verificationUri: Uri.parse('https://example.test'),
        codeDestination: HarnessAuthCodeDestination.browser,
        userCode: 'EXACT-CODE',
      ),
      onOpenAuthorizationPage: () {},
      onCopyCode: (_) {},
      onSubmitCode: (_) {},
      onCancel: () {},
      onRetry: () {},
    )));

    await tester.tap(find.text('[COPY]'));
    await tester.pump();
    expect(message, equals(<String, dynamic>{'text': 'EXACT-CODE'}));
  });

  testWidgets('renders and submits only a trimmed non-empty app code',
      (tester) async {
    final submitted = <String>[];
    await tester.pumpWidget(host(CredentialConnectionView(
      step: BrowserVerificationConnectionStep(
        verificationUri: Uri.parse('https://example.test'),
        codeDestination: HarnessAuthCodeDestination.app,
      ),
      onOpenAuthorizationPage: () {},
      onCopyCode: (_) {},
      onSubmitCode: submitted.add,
      onCancel: () {},
      onRetry: () {},
    )));

    expect(find.text('[OPEN AUTHORIZATION PAGE]'), findsOneWidget);
    expect(find.byType(TerminalTextField), findsOneWidget);
    expect(find.text('[SUBMIT]'), findsOneWidget);
    await tester.tap(find.text('[SUBMIT]'));
    expect(submitted, isEmpty);
    await tester.enterText(find.byType(TextField), '  claude-code  ');
    await tester.tap(find.text('[SUBMIT]'));
    expect(submitted, equals(<String>['claude-code']));
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('[SUBMIT]'));
    expect(submitted, equals(<String>['claude-code']));
  });
}
