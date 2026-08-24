import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/observability/observability_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';
import 'package:pocketcoder_flutter/presentation/observability/agent_observability_screen.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  testWidgets('renders container tiles as selectable BiosRows', (tester) async {
    await tester.pumpWidget(_app(AgentObservabilityView(
      state: const ObservabilityState(currentContainer: 'pocketcoder-mcp-gateway'),
      onRefresh: () {},
      onSelectContainer: (_) {},
    )));

    expect(find.byType(BiosRow), findsNWidgets(4));
    expect(find.text('POCKETBASE'), findsOneWidget);
    expect(find.text('POCKETCODER-MCP-GATEWAY'), findsOneWidget);
  });
}
