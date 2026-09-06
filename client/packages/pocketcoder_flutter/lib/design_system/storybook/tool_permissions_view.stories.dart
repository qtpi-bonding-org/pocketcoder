import 'package:flutter/material.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as wb;
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:pocketcoder_flutter/application/tool_permissions/tool_permissions_state.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/tool_permissions/widgets/tool_permissions_view.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: child,
    );

@wb.UseCase(name: 'no rules', type: ToolPermissionsView)
Widget toolPermissionsViewEmpty(BuildContext context) =>
    _app(ToolPermissionsView(
      state: const ToolPermissionsState(),
      onSetActive: (_, __) async {},
      onUpdateAction: (_, __) async {},
      onCreateRule: (_, __) async {},
    ));

@wb.UseCase(name: 'populated rules', type: ToolPermissionsView)
Widget toolPermissionsViewPopulated(BuildContext context) =>
    _app(ToolPermissionsView(
      state: ToolPermissionsState(status: UiFlowStatus.success, rules: [
        ToolPermission(
          id: 'rule-1',
          tool: 'shell',
          pattern: 'rm *',
          action: ToolPermissionAction.deny,
          active: true,
        ),
        ToolPermission(
          id: 'rule-2',
          tool: 'read',
          pattern: '*',
          action: ToolPermissionAction.allow,
          active: true,
        ),
      ]),
      onSetActive: (_, __) async {},
      onUpdateAction: (_, __) async {},
      onCreateRule: (_, __) async {},
    ));
