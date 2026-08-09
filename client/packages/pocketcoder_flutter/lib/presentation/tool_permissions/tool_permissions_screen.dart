import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/application/tool_permissions/tool_permissions_cubit.dart';
import 'package:pocketcoder_flutter/application/tool_permissions/tool_permissions_state.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'adapters/tool_permissions_adapter.dart';

class ToolPermissionsScreen extends StatelessWidget {
  const ToolPermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<ToolPermissionsCubit>()..watchRules(),
      child: const ToolPermissionsAdapter(),
    );
  }
}

class ToolPermissionsView extends StatelessWidget {
  const ToolPermissionsView({
    super.key,
    required this.state,
    required this.onSetActive,
    required this.onUpdateAction,
    required this.onCreateRule,
  });

  final ToolPermissionsState state;
  final Future<void> Function(String id, bool active) onSetActive;
  final Future<void> Function(String id, String action) onUpdateAction;
  final Future<void> Function(String tool, String action) onCreateRule;

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: context.l10n.toolPermissionsScreenTitle,
      activePillar: NavPillar.configure,
      showBack: true,
      body: BiosFrame(
        title: context.l10n.toolPermissionsRulesRegistry,
        child: Builder(
          builder: (context) {
            final colors = context.colorScheme;
            return state.maybeWhen(
              loaded: (rules) {
                return ListView(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(AppSizes.space),
                      child: TerminalButton(
                        label: 'ADD RULE',
                        onTap: () => _showAddRuleDialog(context),
                      ),
                    ),
                    if (rules.isNotEmpty)
                      BiosSection(
                        title: context.l10n.toolPermissionsRulesRegistry,
                        child: Column(
                          children:
                              rules.map((r) => _buildRuleItem(context, r)).toList(),
                        ),
                      ),
                    if (rules.isEmpty)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSizes.space * 4),
                          child: TerminalText(
                            context.l10n.toolPermissionsNoRules,
                            alpha: 0.5,
                          ),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (msg) => Center(
                child: Text(
                  'ERROR: $msg',
                  style: TextStyle(color: colors.error),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRuleItem(BuildContext context, ToolPermission rule) {
    final isActive = rule.active == true;

    return TerminalCard(
      isActive: isActive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: TerminalText(
                  rule.tool.toUpperCase(),
                  weight: TerminalTextWeight.heavy,
                ),
              ),
              Switch(
                value: isActive,
                onChanged: (value) => onSetActive(rule.id, value),
              ),
            ],
          ),
          VSpace.x1,
          _buildActionSelector(context, rule),
        ],
      ),
    );
  }

  Widget _buildActionSelector(BuildContext context, ToolPermission rule) {
    Widget actionButton(String label, ToolPermissionAction action, String value) {
      return Expanded(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.space / 2),
          child: TerminalButton(
            label: label,
            isPrimary: rule.action == action,
            onTap: () => onUpdateAction(rule.id, value),
          ),
        ),
      );
    }

    return Row(
      children: [
        actionButton(context.l10n.toolPermissionsAllowLabel,
            ToolPermissionAction.allow, 'allow'),
        actionButton(context.l10n.toolPermissionsAskLabel,
            ToolPermissionAction.ask, 'ask'),
        actionButton(context.l10n.toolPermissionsDenyLabel,
            ToolPermissionAction.deny, 'deny'),
      ],
    );
  }

  void _showAddRuleDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final toolController = TextEditingController();
    String selectedAction = 'allow';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setState) => TerminalDialog(
          title: context.l10n.toolPermissionsAddRuleTitle,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TerminalTextField(
                controller: toolController,
                label: context.l10n.toolPermissionsToolNameLabel,
                obscureText: false,
              ),
              VSpace.x2,
              Row(
                children: [
                  ('allow', context.l10n.toolPermissionsAllowLabel),
                  ('ask', context.l10n.toolPermissionsAskLabel),
                  ('deny', context.l10n.toolPermissionsDenyLabel),
                ].map((entry) {
                  final (value, label) = entry;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.space / 2),
                      child: TerminalButton(
                        label: label,
                        isPrimary: selectedAction == value,
                        onTap: () => setState(() => selectedAction = value),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.onSurface,
                side:
                    BorderSide(color: colors.onSurface.withValues(alpha: 0.3)),
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero),
              ),
              child: Text(context.l10n.actionCancel),
            ),
            HSpace.x2,
            OutlinedButton(
              onPressed: () {
                final tool = toolController.text.trim();
                if (tool.isEmpty) return;
                onCreateRule(tool, selectedAction);
                Navigator.of(dialogContext).pop();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.primary,
                side: BorderSide(color: colors.primary),
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero),
              ),
              child: Text(context.l10n.actionAdd),
            ),
          ],
        ),
      ),
    );
  }
}
