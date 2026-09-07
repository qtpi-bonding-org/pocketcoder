import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as wb;
import 'package:pocketcoder_flutter/application/permission_modes/permission_mode_rules_state.dart';
import 'package:pocketcoder_flutter/application/permission_modes/permission_modes_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/permission_mode.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/permission_modes/widgets/permission_mode_rules_view.dart';
import 'package:pocketcoder_flutter/presentation/permission_modes/widgets/permission_modes_view.dart';

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

@wb.UseCase(name: 'no rules', type: PermissionModeRulesView)
Widget permissionModeRulesViewEmpty(BuildContext context) =>
    _app(PermissionModeRulesView(
      title: 'manual',
      readOnly: false,
      state: const PermissionModeRulesState(status: UiFlowStatus.success),
      onSetActive: (_, __) async {},
      onUpdateAction: (_, __) async {},
      onCreateRule: (_, __) async {},
    ));

@wb.UseCase(name: 'populated rules', type: PermissionModeRulesView)
Widget permissionModeRulesViewPopulated(BuildContext context) =>
    _app(PermissionModeRulesView(
      title: 'personal rules',
      readOnly: false,
      state: PermissionModeRulesState(status: UiFlowStatus.success, rules: [
        ToolPermission(
          id: 'rule-1',
          tool: 'shell',
          pattern: 'rm *',
          action: ToolPermissionAction.deny,
          active: true,
          permissionMode: 'mode-1',
        ),
        ToolPermission(
          id: 'rule-2',
          tool: 'read',
          pattern: '*',
          action: ToolPermissionAction.allow,
          active: true,
          permissionMode: 'mode-1',
        ),
      ]),
      onSetActive: (_, __) async {},
      onUpdateAction: (_, __) async {},
      onCreateRule: (_, __) async {},
    ));

@wb.UseCase(name: 'mode registry', type: PermissionModesView)
Widget permissionModesViewPopulated(BuildContext context) =>
    _app(PermissionModesView(
      state: PermissionModesState(
        status: UiFlowStatus.success,
        modes: const [
          PermissionMode(
            id: 'manual',
            name: 'manual',
            description: 'Ask before every tool call.',
            baseSessionMode: PermissionModeBaseSessionMode.approve,
            isSystem: true,
            isDefault: true,
          ),
          PermissionMode(
            id: 'custom',
            name: 'workspace mode',
            description: 'A personal set of rules.',
            baseSessionMode: PermissionModeBaseSessionMode.approve,
            isSystem: false,
          ),
        ],
      ),
      onOpenMode: (_) {},
      onDuplicateMode: (_, __) async {},
      onDeleteMode: (_) async {},
    ));
