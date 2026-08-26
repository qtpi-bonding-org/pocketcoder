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
  testWidgets('renders backend health and the discovered container registry',
      (tester) async {
    await tester.pumpWidget(_app(MonitorView(
      state: const ObservabilityState(
        stats: SystemStats(backendStatus: 'ready'),
        containers: [
          ContainerInfo(name: 'pocketcoder-sqlpage', state: 'running', status: 'Up 1h'),
          ContainerInfo(name: 'pocketcoder-ollama', state: 'exited', status: 'Exited (0)'),
        ],
      ),
      onRefresh: () {},
      onSelectContainer: (_) {},
    )));

    expect(find.byType(BiosRow), findsWidgets);
    expect(find.text('BACKEND STATUS'), findsOneWidget);
    // BiosRow uppercases its label before rendering.
    expect(find.text('POCKETCODER-SQLPAGE'), findsOneWidget);
    expect(find.text('POCKETCODER-OLLAMA'), findsOneWidget);
  });

  testWidgets('selecting a container drives onSelectContainer', (tester) async {
    String? selected;
    await tester.pumpWidget(_app(MonitorView(
      state: const ObservabilityState(
        containers: [ContainerInfo(name: 'pocketcoder-sqlpage', state: 'running', status: 'Up 1h')],
      ),
      onRefresh: () {},
      onSelectContainer: (c) => selected = c,
    )));

    await tester.tap(find.text('POCKETCODER-SQLPAGE'));
    expect(selected, 'pocketcoder-sqlpage');
  });

  testWidgets('shows the log terminal for the currently selected container',
      (tester) async {
    await tester.pumpWidget(_app(MonitorView(
      state: const ObservabilityState(
        currentContainer: 'pocketcoder-sqlpage',
        logs: ['line one', 'line two'],
      ),
      onRefresh: () {},
      onSelectContainer: (_) {},
    )));

    expect(find.text('line one'), findsOneWidget);
    expect(find.text('line two'), findsOneWidget);
  });

  testWidgets('no key metrics, token usage, or agent activity sections remain',
      (tester) async {
    await tester.pumpWidget(_app(MonitorView(
      state: const ObservabilityState(
        stats: SystemStats(backendStatus: 'ready', tokenUsage: [TokenUsage(model: 'gpt-4', tokens: 1)]),
      ),
      onRefresh: () {},
      onSelectContainer: (_) {},
    )));

    // These l10n labels belonged only to the removed sections.
    expect(find.text('KEY METRICS'), findsNothing);
    expect(find.text('TOKEN USAGE BY MODEL'), findsNothing);
    expect(find.text('AGENT ACTIVITY'), findsNothing);
  });
}
