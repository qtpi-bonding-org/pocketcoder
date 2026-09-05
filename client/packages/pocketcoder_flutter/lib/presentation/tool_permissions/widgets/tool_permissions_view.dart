import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/decision_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/section_header.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_spinner.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/application/tool_permissions/tool_permissions_state.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:pocketcoder_flutter/presentation/core/safe_error_message.dart';

import 'tool_permission_dialogs.dart';

class ToolPermissionsView extends StatelessWidget {
  const ToolPermissionsView(
      {super.key,
      required this.state,
      required this.onSetActive,
      required this.onUpdateAction,
      required this.onCreateRule});

  final ToolPermissionsState state;
  final Future<void> Function(String id, bool active) onSetActive;
  final Future<void> Function(String id, String action) onUpdateAction;
  final Future<void> Function(String tool, String action) onCreateRule;

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
        footer: buildPillarFooter(context, NavPillar.config),
        showBack: true,
        body: DecisionFrame(
            title: context.l10n.toolPermissionsRulesRegistry.toLowerCase(),
            child: Builder(builder: (context) {
              if (state.status == UiFlowStatus.loading) {
                return const Center(child: TerminalSpinner());
              }
              if (state.status == UiFlowStatus.failure) {
                return Center(
                    child: TerminalText(safeErrorMessage(state.error),
                        role: TextRole.warn));
              }
              if (state.status != UiFlowStatus.success) {
                return const SizedBox.shrink();
              }
              final rules = state.rules;
              return ListView(children: [
                Padding(
                    padding: EdgeInsets.all(AppSizes.space),
                    child: TerminalButton(
                        label: context.l10n.toolPermissionsAddRuleButton,
                        onTap: () => showAddRuleDialog(context, onCreateRule))),
                if (rules.isNotEmpty) ...[
                  SectionHeader(
                      name: context.l10n.toolPermissionsRulesRegistry
                          .toLowerCase()),
                  Column(
                      children: rules
                          .map((r) => _buildRuleItem(context, r))
                          .toList()),
                ],
                if (rules.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSizes.space * 4),
                      child: TerminalText(
                        context.l10n.toolPermissionsNoRules,
                        role: TextRole.body,
                      ),
                    ),
                  ),
              ]);
            })));
  }

  Widget _buildRuleItem(BuildContext context, ToolPermission rule) {
    final isActive = rule.active == true;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DetailRow.toggle(
          label: rule.tool,
          value: isActive,
          onChanged: (value) => onSetActive(rule.id, value)),
      VSpace.x1,
      BiosActionStrip(actions: [
        BiosActionStripItem(
            label: context.l10n.toolPermissionsAllowLabel,
            isActive: rule.action == ToolPermissionAction.allow,
            onTap: () => onUpdateAction(rule.id, 'allow')),
        BiosActionStripItem(
            label: context.l10n.toolPermissionsAskLabel,
            isActive: rule.action == ToolPermissionAction.ask,
            onTap: () => onUpdateAction(rule.id, 'ask')),
        BiosActionStripItem(
            label: context.l10n.toolPermissionsDenyLabel,
            isActive: rule.action == ToolPermissionAction.deny,
            onTap: () => onUpdateAction(rule.id, 'deny')),
      ]),
      VSpace.x2,
    ]);
  }
}
