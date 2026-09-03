import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/system/health_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/healthcheck.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';
import 'package:pocketcoder_flutter/presentation/system/widgets/system_checks_view.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  testWidgets('renders each check as a BiosRow', (tester) async {
    await tester.pumpWidget(_app(SystemChecksView(
      state: HealthState(checks: [
        Healthcheck(id: '1', name: 'database', status: HealthcheckStatus.ready),
      ]),
      onRefresh: () {},
    )));

    expect(find.byType(BiosRow), findsOneWidget);
    expect(find.text('DATABASE'), findsOneWidget);
    expect(find.text('[READY]'), findsOneWidget);
  });
}
