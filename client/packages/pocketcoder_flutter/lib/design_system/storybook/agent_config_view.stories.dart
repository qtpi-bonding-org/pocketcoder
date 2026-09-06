import 'package:flutter/material.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as wb;
import 'package:pocketcoder_flutter/application/agent_config/agent_config_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/agent_config/widgets/agent_config_view.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

@wb.UseCase(name: 'empty registry', type: AgentConfigView)
Widget agentConfigEmpty(BuildContext context) => _app(AgentConfigView(
      state: const AgentConfigState(status: UiFlowStatus.success),
      onSave: (_) async {},
      onDelete: (_) async {},
    ));

@wb.UseCase(name: 'loading registry', type: AgentConfigView)
Widget agentConfigLoading(BuildContext context) => _app(AgentConfigView(
      state: const AgentConfigState(status: UiFlowStatus.loading),
      onSave: (_) async {},
      onDelete: (_) async {},
    ));
