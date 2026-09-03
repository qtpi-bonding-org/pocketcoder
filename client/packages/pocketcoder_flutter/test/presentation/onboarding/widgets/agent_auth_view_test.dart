import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/agent_auth_view.dart';

Harnesse _goose() => const Harnesse(
      id: 'goose-1',
      name: 'Goose',
      cliId: 'goose',
      acpTransport: HarnesseAcpTransport.websocket,
      providerFanout: true,
    );

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.terminalTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  testWidgets('a harness card dims while providers are still loading',
      (tester) async {
    await tester.pumpWidget(_wrap(AgentAuthView(
      status: UiFlowStatus.success,
      harnesses: [_goose()],
      error: null,
      onSelected: (_) {},
      harnessProvidersLoaded: false,
      onSkip: () {},
      selectedHarnesses: const ['goose'],
    )));
    await tester.pump();

    final loadingOpacity = tester
        .widget<Opacity>(
            find.byKey(const ValueKey('harness-card-opacity-goose')))
        .opacity;
    expect(loadingOpacity, lessThan(1.0));
  });

  testWidgets('a harness card is at full opacity once providers load',
      (tester) async {
    await tester.pumpWidget(_wrap(AgentAuthView(
      status: UiFlowStatus.success,
      harnesses: [_goose()],
      error: null,
      onSelected: (_) {},
      harnessProvidersLoaded: true,
      onSkip: () {},
      selectedHarnesses: const ['goose'],
    )));
    await tester.pump();

    final loadingOpacity = tester
        .widget<Opacity>(
            find.byKey(const ValueKey('harness-card-opacity-goose')))
        .opacity;
    expect(loadingOpacity, 1.0);
  });
}
