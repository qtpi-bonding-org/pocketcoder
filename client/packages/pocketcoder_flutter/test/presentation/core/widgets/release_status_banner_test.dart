import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/release_status/release_status_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/release_status_banner.dart';

const _digest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Widget _app(ReleaseStatusState state) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ReleaseStatusBanner(state: state, onDismiss: () {}),
      ),
    );

ReleaseStatusState _state(ServerReleaseStatus status) => ReleaseStatusState(
      snapshot: ServerReleaseStatusSnapshot(
        status: status,
        currentVersion: '1.0.0',
        currentDataVersion: 1,
        currentReleaseDigest: _digest,
        checkedAt: DateTime.utc(2026, 8, 12),
        summary: status == ServerReleaseStatus.criticalReleaseWarning
            ? 'Unsafe release.'
            : null,
      ),
    );

void main() {
  testWidgets('ordinary update notice is dismissible', (tester) async {
    await tester.pumpWidget(_app(_state(ServerReleaseStatus.updateAvailable)));

    expect(find.text(r'$ UPDATE AVAILABLE'), findsOneWidget);
    expect(find.text('DISMISS'), findsOneWidget);
  });

  testWidgets('critical warning is persistent', (tester) async {
    await tester.pumpWidget(
      _app(_state(ServerReleaseStatus.criticalReleaseWarning)),
    );

    expect(find.textContaining(r'$ CRITICAL RELEASE WARNING'), findsOneWidget);
    expect(find.text('DISMISS'), findsNothing);
  });
}
