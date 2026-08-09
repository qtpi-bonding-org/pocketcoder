import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as wb;
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/agent/widgets/plan_panel.dart';

Widget _app(Widget child) => MaterialApp(theme: AppTheme.lightTheme, home: child);

@wb.UseCase(name: 'no plan', type: PlanPanel)
Widget planPanelEmpty(BuildContext context) => _app(const PlanPanel(plan: null));

@wb.UseCase(name: 'active and completed tasks', type: PlanPanel)
Widget planPanelPopulated(BuildContext context) => _app(const PlanPanel(plan: {
  'entries': [
    {'content': 'Review the deployment configuration', 'priority': 'high', 'status': 'completed'},
    {'content': 'Run the production smoke test', 'priority': 'normal', 'status': 'in_progress'},
    {'content': 'Publish the release notes', 'priority': 'low', 'status': 'pending'},
  ],
}));
