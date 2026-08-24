import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/observability/observability_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/observability/i_observability_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';
import 'package:pocketcoder_flutter/presentation/monitor/monitor_screen.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  testWidgets('renders health and token usage entries as BiosRows',
      (tester) async {
    await tester.pumpWidget(_app(MonitorView(
      state: ObservabilityState(
        stats: SystemStats(
          backendStatus: 'ready',
          tokenUsage: [TokenUsage(model: 'gpt-4', tokens: 1234)],
        ),
      ),
      onRefresh: () {},
    )));

    expect(find.byType(BiosRow), findsNWidgets(2));
    expect(find.text('BACKEND STATUS'), findsOneWidget);
    expect(find.text('GPT-4'), findsOneWidget);
    expect(find.text('1.2K'), findsOneWidget);
  });
}
