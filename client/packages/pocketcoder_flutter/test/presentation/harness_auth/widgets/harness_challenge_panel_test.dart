import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/harness_auth/widgets/harness_auth_view.dart';

void main() {
  Future<void> pumpPanel(WidgetTester tester, HarnessAuthChallenge challenge) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: HarnessChallengePanel(challenge: challenge)),
      ),
    );
  }

  testWidgets('shows a [COPY] action for the device-flow code in details',
      (tester) async {
    await pumpPanel(
      tester,
      const HarnessAuthChallenge(
        type: 'device',
        text: 'Visit the link and enter the code below.',
        target: 'https://example.test/device',
        details: 'ABCD-1234',
      ),
    );

    expect(find.text('[COPY]'), findsOneWidget);
  });

  testWidgets('tapping [COPY] copies the code (details) to the clipboard',
      (tester) async {
    final copied = <ClipboardData>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add(ClipboardData(text: call.arguments['text'] as String));
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await pumpPanel(
      tester,
      const HarnessAuthChallenge(
        type: 'device',
        text: 'Visit the link and enter the code below.',
        target: 'https://example.test/device',
        details: 'ABCD-1234',
      ),
    );

    await tester.tap(find.text('[COPY]'));
    await tester.pump();

    expect(copied, hasLength(1));
    expect(copied.single.text, 'ABCD-1234');
  });

  testWidgets('does not show a [COPY] action when there is no code to copy',
      (tester) async {
    await pumpPanel(
      tester,
      const HarnessAuthChallenge(
        type: 'device',
        text: 'Visit the link and sign in.',
        target: 'https://example.test/device',
      ),
    );

    expect(find.text('[COPY]'), findsNothing);
  });
}
