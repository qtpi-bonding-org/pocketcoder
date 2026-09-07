import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/design_system/primitives/row_affordance.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/section_header.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_spinner.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_list_picker_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/safe_error_message.dart';
import 'package:pocketcoder_flutter/application/permission_modes/permission_modes_state.dart';
import 'package:pocketcoder_flutter/domain/models/permission_mode.dart';

import 'permission_mode_editor_dialog.dart';

class PermissionModesView extends StatelessWidget {
  const PermissionModesView({
    super.key,
    required this.state,
    required this.onOpenMode,
    required this.onDuplicateMode,
    required this.onDeleteMode,
  });

  final PermissionModesState state;
  final void Function(PermissionMode mode) onOpenMode;
  final Future<void> Function(PermissionMode source, String newName)
      onDuplicateMode;
  final Future<void> Function(String id) onDeleteMode;

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
        footer: buildPillarFooter(context, NavPillar.config),
        showBack: true,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
                name: context.l10n.permissionModesRegistry.toLowerCase()),
            Expanded(
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
                final modes = state.modes;
                return ListView(children: [
                  Padding(
                      padding: EdgeInsets.all(AppSizes.space),
                      child: TerminalButton(
                          label: context.l10n.permissionModesAddButton,
                          onTap: () => _showDuplicateFlow(context, modes))),
                  ...modes.map((mode) => _buildModeRow(context, mode)),
                ]);
              }),
            ),
          ],
        ));
  }

  Widget _buildModeRow(BuildContext context, PermissionMode mode) {
    final isSystem = mode.isSystem == true;
    return DetailRow(
      label: mode.name,
      value: mode.description ?? '',
      hasBadge: isSystem,
      affordance: RowAffordance.expand,
      onTap: () => onOpenMode(mode),
      trailing: isSystem
          ? null
          : TerminalButton(
              label: context.l10n.actionDelete,
              kind: ActionKind.refusal,
              onTap: () => onDeleteMode(mode.id),
            ),
    );
  }

  Future<void> _showDuplicateFlow(
      BuildContext context, List<PermissionMode> modes) async {
    final source = await showTerminalListPicker<PermissionMode>(
      context: context,
      title: context.l10n.permissionModesDuplicateSourceTitle,
      items: modes,
      itemBuilder: (_, mode) => TerminalText(mode.name, role: TextRole.label),
      emptyLabel: context.l10n.permissionModesNoModes,
      cancelLabel: context.l10n.actionCancel,
    );
    if (source == null || !context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => PermissionModeEditorDialog(
        initialName: '${source.name} copy',
        initialDescription: source.description,
        onSubmit: (name, _) => onDuplicateMode(source, name),
      ),
    );
  }
}
