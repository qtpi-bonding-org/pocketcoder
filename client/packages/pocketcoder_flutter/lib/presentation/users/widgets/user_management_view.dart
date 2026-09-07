import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/auth/user.dart';
import 'package:pocketcoder_flutter/presentation/core/safe_error_message.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/section_header.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_confirm_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_spinner.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/application/users/user_management_state.dart';

import 'user_management_dialogs.dart';

class UserManagementView extends StatelessWidget {
  const UserManagementView({
    super.key,
    required this.state,
    required this.onCreate,
    required this.onResetPassword,
    required this.onDelete,
  });

  final UserManagementState state;
  final Future<String?> Function(String email) onCreate;
  final Future<String?> Function(String userId) onResetPassword;
  final ValueChanged<String> onDelete;

  Future<void> _handleCreate(BuildContext context, String email) async {
    final password = await onCreate(email);
    if (password != null && context.mounted) {
      showRevealPasswordDialog(context, email: email, password: password);
    }
  }

  Future<void> _handleResetPassword(BuildContext context, User user) async {
    final confirmed = await showTerminalConfirmDialog(
      context,
      title: context.l10n.usersResetPasswordConfirmTitle,
      body: context.l10n.usersResetPasswordConfirmBody(user.email),
      cancelLabel: context.l10n.actionCancel,
      confirmLabel: context.l10n.usersResetPasswordButton,
    );
    if (confirmed != true || !context.mounted) return;
    final password = await onResetPassword(user.id);
    if (password != null && context.mounted) {
      showRevealPasswordDialog(context, email: user.email, password: password);
    }
  }

  Future<void> _handleDelete(BuildContext context, User user) async {
    final confirmed = await showTerminalConfirmDialog(
      context,
      title: context.l10n.usersDeleteConfirmTitle,
      body: context.l10n.usersDeleteConfirmBody(user.email),
      cancelLabel: context.l10n.actionCancel,
      confirmLabel: context.l10n.usersDeleteButton,
      danger: true,
    );
    if (confirmed == true) onDelete(user.id);
  }

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      footer: buildPillarFooter(context, NavPillar.config),
      showBack: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(name: context.l10n.usersScreenTitle.toLowerCase()),
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
              final users = state.users;
              return ListView(children: [
                Padding(
                    padding: EdgeInsets.all(AppSizes.space),
                    child: TerminalButton(
                        label: context.l10n.usersAddButton,
                        onTap: () => showAddUserDialog(context,
                            (email) => _handleCreate(context, email)))),
                for (final user in users) _buildUserItem(context, user),
                if (users.isEmpty && state.status == UiFlowStatus.success)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSizes.space * 4),
                      child: TerminalText(context.l10n.usersNoUsers,
                          role: TextRole.body),
                    ),
                  ),
              ]);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildUserItem(BuildContext context, User user) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DetailRow(label: user.email, value: user.role?.name ?? ''),
      VSpace.x1,
      BiosActionStrip(actions: [
        BiosActionStripItem(
            label: context.l10n.usersResetPasswordButton,
            onTap: () => _handleResetPassword(context, user)),
        BiosActionStripItem(
            label: context.l10n.usersDeleteButton,
            kind: ActionKind.destructive,
            onTap: () => _handleDelete(context, user)),
      ]),
      VSpace.x2,
    ]);
  }
}
