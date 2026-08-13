import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/pocketcoder_update/widgets/pocketcoder_update_view.dart';

const _digest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Widget _app({required bool confirmed}) => MaterialApp(
      theme: AppTheme.darkTheme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: PocketCoderUpdateView(
        isLoading: false,
        preview: ServerReleaseStatusSnapshot(
          status: ServerReleaseStatus.updateAvailable,
          currentVersion: '1.0.0',
          currentDataVersion: 1,
          currentReleaseDigest: _digest,
          checkedAt: DateTime.utc(2026, 8, 12),
          availableVersion: '1.1.0',
          availableDataVersion: 2,
          downloadBytes: 104857600,
          requiredDiskBytes: 2147483648,
          normalRollbackAvailableAfterSuccess: false,
        ),
        result: null,
        upgradeConfirmed: confirmed,
        onRefresh: () {},
        onUpdate: () {},
        onDismiss: () {},
      ),
    );

void main() {
  testWidgets('discloses data boundary before upgrade', (tester) async {
    await tester.pumpWidget(_app(confirmed: false));

    expect(find.text('CURRENT: 1.0.0'), findsOneWidget);
    expect(find.text('AVAILABLE: 1.1.0'), findsOneWidget);
    expect(find.text('DATA VERSION 1 → 2'), findsOneWidget);
    expect(find.text('REVIEW DATA CHANGE'), findsOneWidget);
  });

  testWidgets('requires explicit confirmation for cross-data upgrade',
      (tester) async {
    await tester.pumpWidget(_app(confirmed: true));

    expect(find.text('CONFIRM UPGRADE'), findsOneWidget);
  });
}
