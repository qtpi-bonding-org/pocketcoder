import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/observability/observability_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/observability/i_observability_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/decision_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/presentation/monitor/monitor_screen.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  testWidgets('renders the discovered container registry', (tester) async {
    await tester.pumpWidget(_app(MonitorView(
      state: const ObservabilityState(
        containers: [
          ContainerInfo(
              name: 'pocketcoder-sqlpage', state: 'running', status: 'Up 1h'),
          ContainerInfo(
              name: 'pocketcoder-ollama',
              state: 'exited',
              status: 'Exited (0)'),
        ],
      ),
      onSelectContainer: (_) {},
    )));

    expect(find.byType(DetailRow), findsWidgets);
    // DetailRow renders labels as passed, sentence case; the shared
    // "pocketcoder-" compose prefix is stripped since every container on
    // this screen belongs to the same deployment.
    expect(find.text('sqlpage'), findsOneWidget);
    expect(find.text('ollama'), findsOneWidget);
  });

  testWidgets('selecting a container drives onSelectContainer', (tester) async {
    String? selected;
    await tester.pumpWidget(_app(MonitorView(
      state: const ObservabilityState(
        containers: [
          ContainerInfo(
              name: 'pocketcoder-sqlpage', state: 'running', status: 'Up 1h')
        ],
      ),
      onSelectContainer: (c) => selected = c,
    )));

    await tester.tap(find.text('SQLPAGE'));
    expect(selected, 'pocketcoder-sqlpage');
  });

  testWidgets('shows the log terminal for the currently selected container',
      (tester) async {
    await tester.pumpWidget(_app(MonitorView(
      state: const ObservabilityState(
        currentContainer: 'pocketcoder-sqlpage',
        logs: [
          LogEntry(timestamp: null, message: 'line one'),
          LogEntry(timestamp: null, message: 'line two'),
        ],
      ),
      onSelectContainer: (_) {},
    )));

    expect(find.textContaining('line one'), findsOneWidget);
    expect(find.textContaining('line two'), findsOneWidget);
    // Logs render plainly -- the only DecisionFrame left on screen is the
    // Registry list; the log terminal is no longer boxed.
    expect(find.byType(DecisionFrame), findsOneWidget);
  });

  testWidgets(
      'leaves container names without the pocketcoder- prefix unchanged',
      (tester) async {
    await tester.pumpWidget(_app(MonitorView(
      state: const ObservabilityState(
        containers: [
          ContainerInfo(
              name: 'custom-service', state: 'running', status: 'Up 1h')
        ],
      ),
      onSelectContainer: (_) {},
    )));

    expect(find.text('CUSTOM-SERVICE'), findsOneWidget);
  });

  testWidgets('no key metrics, token usage, or agent activity sections remain',
      (tester) async {
    await tester.pumpWidget(_app(MonitorView(
      state: const ObservabilityState(
        stats: SystemStats(tokenUsage: [TokenUsage(model: 'gpt-4', tokens: 1)]),
      ),
      onSelectContainer: (_) {},
    )));

    // These l10n labels belonged only to the removed sections.
    expect(find.text('KEY METRICS'), findsNothing);
    expect(find.text('TOKEN USAGE BY MODEL'), findsNothing);
    expect(find.text('AGENT ACTIVITY'), findsNothing);
  });
}
