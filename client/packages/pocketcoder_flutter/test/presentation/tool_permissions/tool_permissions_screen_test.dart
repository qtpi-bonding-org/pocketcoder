import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/tool_permissions/tool_permissions_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_row.dart';
import 'package:pocketcoder_flutter/presentation/tool_permissions/tool_permissions_screen.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  testWidgets(
      'renders a rule as a BiosRow toggle header + BiosActionStrip selector',
      (tester) async {
    var setActiveCalled = false;
    await tester.pumpWidget(_app(ToolPermissionsView(
      state: ToolPermissionsState(
        status: UiFlowStatus.success,
        rules: [
          ToolPermission(
            id: 'r1',
            tool: 'bash',
            pattern: '.*',
            action: ToolPermissionAction.allow,
            active: true,
          ),
        ],
      ),
      onSetActive: (id, active) async => setActiveCalled = true,
      onUpdateAction: (id, action) async {},
      onCreateRule: (tool, action) async {},
    )));

    expect(find.byType(BiosRow), findsWidgets);
    expect(find.byType(BiosActionStrip), findsOneWidget);

    final toggleRow = tester
        .widgetList<BiosRow>(find.byType(BiosRow))
        .firstWhere((row) => row.variant == BiosRowVariant.toggle);
    expect(toggleRow.toggleValue, isTrue);
    expect(find.byType(Switch), findsNothing);
    await tester.tap(find.text('[X]'));
    expect(setActiveCalled, isTrue);
  });
}
