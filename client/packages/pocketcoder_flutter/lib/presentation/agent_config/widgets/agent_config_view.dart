import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/application/agent_config/agent_config_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/poco_config.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/decision_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/section_header.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/agent_config/widgets/agent_config_editor_dialog.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';

class AgentConfigView extends StatelessWidget {
  const AgentConfigView(
      {super.key,
      required this.state,
      required this.onSave,
      required this.onDelete});
  final AgentConfigState state;
  final Future<void> Function(PocoConfig) onSave;
  final Future<void> Function(String) onDelete;

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
        footer: buildPillarFooter(context, NavPillar.config),
        showBack: true,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(name: context.l10n.agentConfigTitle.toLowerCase()),
            Expanded(
              child: DecisionFrame(
                  title: context.l10n.agentConfigRegistry.toLowerCase(),
                  child: _buildBody(context, state)),
            ),
          ],
        ));
  }

  Widget _buildBody(BuildContext context, AgentConfigState state) {
    if (state.isLoading && state.configs.isEmpty) {
      return Center(
          child: TerminalLoadingIndicator(label: context.l10n.agentSearching));
    }

    if (state.isFailure && state.configs.isEmpty) {
      return Center(
          child: TerminalText(
              context.l10n.agentConfigErrorPrefix(
                  state.error?.toString() ?? context.l10n.errorGeneric),
              role: TextRole.warn,
              textAlign: TextAlign.center));
    }

    return Column(children: [
      Padding(
          padding: EdgeInsets.all(AppSizes.space),
          child: TerminalButton(
              label: context.l10n.actionAddNew,
              onTap: () => _openEditor(context, null))),
      Expanded(
          child: state.configs.isEmpty
              ? Center(
                  child: TerminalText(
                  context.l10n.agentConfigEmpty,
                  role: TextRole.label,
                ))
              : ListView.builder(
                  itemCount: state.configs.length,
                  itemBuilder: (context, index) {
                    final config = state.configs[index];
                    final isDefault = config.isDefault ?? false;
                    return DetailRow(
                        label: config.name.toUpperCase(),
                        value: isDefault
                            ? context.l10n.agentConfigDefaultBadge
                            : _permissionModeLabelFor(config),
                        hasBadge: isDefault,
                        onTap: () => _openEditor(context, config));
                  })),
    ]);
  }

  String _permissionModeLabelFor(PocoConfig config) =>
      state.permissionModes
          .where((m) => m.id == config.permissionMode)
          .firstOrNull
          ?.name
          .toUpperCase() ??
      '';

  void _openEditor(BuildContext context, PocoConfig? existing) {
    showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AgentConfigEditorDialog(
              existing: existing,
              prompts: state.prompts,
              permissionModes: state.permissionModes,
              onSave: (updated) {
                onSave(updated);
                Navigator.of(dialogContext).pop();
              },
              onDelete: existing != null && existing.id.isNotEmpty
                  ? () async {
                      final confirmed =
                          await _confirmDelete(dialogContext, existing);
                      if (confirmed == true) {
                        onDelete(existing.id);
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      }
                    }
                  : null);
        });
  }

  Future<bool?> _confirmDelete(
      BuildContext dialogContext, PocoConfig existing) {
    return showDialog<bool>(
        context: dialogContext,
        builder: (confirmContext) => TerminalDialog(
                title: dialogContext.l10n.agentConfigDeleteConfirmTitle
                    .toLowerCase(),
                content: TerminalText(
                  dialogContext.l10n.agentConfigDeleteConfirmBody(
                      existing.name.toUpperCase()),
                  role: TextRole.body,
                ),
                actions: [
                  TerminalButton(
                      label: dialogContext.l10n.actionCancel,
                      kind: ActionKind.neutral,
                      onTap: () => Navigator.of(confirmContext).pop(false)),
                  HSpace.x2,
                  TerminalButton(
                      label: dialogContext.l10n.agentConfigDelete,
                      onTap: () => Navigator.of(confirmContext).pop(true)),
                ]));
  }
}
