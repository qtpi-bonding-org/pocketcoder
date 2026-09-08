import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/permission_modes/permission_mode_rules_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_spinner.dart';
import 'package:pocketcoder_flutter/presentation/permission_modes/widgets/permission_mode_rules_view.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

ToolPermission _rule() => ToolPermission(
      id: 'rule-1',
      tool: 'bash',
      pattern: 'ls *',
      action: ToolPermissionAction.allow,
      active: true,
      permissionMode: 'mode-1',
    );

void main() {
  testWidgets('renders rules and invokes active callback', (tester) async {
    var called = false;
    await tester.pumpWidget(_app(PermissionModeRulesView(
      title: 'read',
      readOnly: false,
      state: PermissionModeRulesState(
        status: UiFlowStatus.success,
        rules: [_rule()],
      ),
      onSetActive: (_, __) async => called = true,
      onUpdateAction: (_, __) async {},
      onCreateRule: (_, __) async {},
    )));

    expect(find.byType(DetailRow), findsWidgets);
    expect(find.byType(BiosActionStrip), findsOneWidget);
    await tester.tap(find.text('on'));
    expect(called, isTrue);
  });

  testWidgets('shows loading spinner', (tester) async {
    await tester.pumpWidget(_app(PermissionModeRulesView(
      title: 'read',
      readOnly: false,
      state: const PermissionModeRulesState(status: UiFlowStatus.loading),
      onSetActive: (_, __) async {},
      onUpdateAction: (_, __) async {},
      onCreateRule: (_, __) async {},
    )));

    expect(find.byType(TerminalSpinner), findsOneWidget);
  });

  testWidgets('shows failure message', (tester) async {
    await tester.pumpWidget(_app(PermissionModeRulesView(
      title: 'read',
      readOnly: false,
      state: const PermissionModeRulesState(
        status: UiFlowStatus.failure,
        error: 'unable to load rules',
      ),
      onSetActive: (_, __) async {},
      onUpdateAction: (_, __) async {},
      onCreateRule: (_, __) async {},
    )));

    expect(find.text('error.generic'), findsOneWidget);
  });

  testWidgets('read-only rules hide add rule button', (tester) async {
    await tester.pumpWidget(_app(PermissionModeRulesView(
      title: 'manual',
      readOnly: true,
      state: PermissionModeRulesState(
        status: UiFlowStatus.success,
        rules: [_rule()],
      ),
      onSetActive: (_, __) async {},
      onUpdateAction: (_, __) async {},
      onCreateRule: (_, __) async {},
    )));

    expect(find.text('add rule'), findsNothing);
  });
}
