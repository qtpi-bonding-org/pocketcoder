import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/git_repository_access.dart';
import 'package:pocketcoder_flutter/domain/models/git_ssh_credential.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_checkbox.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog_actions.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/server_control/widgets/copy_button.dart';

void showAddAccountKeyDialog(
  BuildContext context,
  Future<void> Function(String label) onCreate,
) {
  final labelController = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (dialogContext) => TerminalDialog(
      title: context.l10n.gitSshAddAccountKeyTitle.toLowerCase(),
      content: TerminalTextField(
        controller: labelController,
        label: context.l10n.gitSshLabelField,
      ),
      actions: [
        TerminalDialogActions(actions: [
          TerminalActionSpec(context.l10n.actionCancel, ActionKind.refusal,
              () => Navigator.of(dialogContext).pop()),
          TerminalActionSpec(context.l10n.actionAdd, ActionKind.primary, () {
            final label = labelController.text.trim();
            if (label.isEmpty) return;
            Navigator.of(dialogContext).pop();
            onCreate(label);
          }),
        ]),
      ],
    ),
  );
}

void showPublicKeyDialog(
  BuildContext context, {
  required String label,
  required String publicKey,
}) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => TerminalDialog(
      title: label.toLowerCase(),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TerminalText(context.l10n.gitSshPublicKeyDialogBody,
              role: TextRole.body),
          VSpace.x2,
          TerminalText(publicKey, role: TextRole.value),
          VSpace.x1,
          CopyButton(value: publicKey),
        ],
      ),
      actions: [
        TerminalDialogActions(actions: [
          TerminalActionSpec(context.l10n.actionDone, ActionKind.primary,
              () => Navigator.of(dialogContext).pop()),
        ]),
      ],
    ),
  );
}

void showAddRepositoryAccessDialog(
  BuildContext context, {
  required List<GitSshCredential> accountKeys,
  required Future<void> Function({
    required GitRepositoryAccessProvider provider,
    required String repository,
    required String purpose,
    required GitRepositoryAccessCredentialMode credentialMode,
    required GitRepositoryAccessRequestedAccess requestedAccess,
    String? credential,
    String? host,
    int? port,
  }) onCreate,
}) {
  final repositoryController = TextEditingController();
  final purposeController = TextEditingController();
  final hostController = TextEditingController();
  final portController = TextEditingController(text: '22');
  var provider = GitRepositoryAccessProvider.github;
  var credentialMode = GitRepositoryAccessCredentialMode.generatedDeploy;
  var requestedAccess = GitRepositoryAccessRequestedAccess.readOnly;
  String? selectedAccountKeyId =
      accountKeys.isNotEmpty ? accountKeys.first.id : null;

  showDialog<void>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (dialogContext, setState) => TerminalDialog(
        title: context.l10n.gitSshAddRepositoryAccessTitle.toLowerCase(),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _choiceRow<GitRepositoryAccessProvider>(
              context,
              value: provider,
              options: const [
                (GitRepositoryAccessProvider.github, 'GitHub'),
                (GitRepositoryAccessProvider.gitlab, 'GitLab'),
                (GitRepositoryAccessProvider.codeberg, 'Codeberg'),
                (GitRepositoryAccessProvider.custom, 'Custom'),
              ],
              onSelected: (v) => setState(() => provider = v),
            ),
            VSpace.x2,
            TerminalTextField(
              controller: repositoryController,
              label: context.l10n.gitSshRepositoryField,
              hint: context.l10n.gitSshRepositoryFieldHint,
            ),
            VSpace.x2,
            TerminalTextField(
              controller: purposeController,
              label: context.l10n.gitSshPurposeField,
            ),
            if (provider == GitRepositoryAccessProvider.custom) ...[
              VSpace.x2,
              TerminalTextField(
                controller: hostController,
                label: context.l10n.gitSshHostField,
              ),
              VSpace.x2,
              TerminalTextField(
                controller: portController,
                label: context.l10n.gitSshPortField,
              ),
            ],
            VSpace.x2,
            _choiceRow<GitRepositoryAccessCredentialMode>(
              context,
              value: credentialMode,
              options: [
                (
                  GitRepositoryAccessCredentialMode.generatedDeploy,
                  context.l10n.gitSshCredentialModeDeploy
                ),
                (
                  GitRepositoryAccessCredentialMode.existingAccount,
                  context.l10n.gitSshCredentialModeAccount
                ),
              ],
              onSelected: (v) => setState(() => credentialMode = v),
            ),
            if (credentialMode ==
                GitRepositoryAccessCredentialMode.existingAccount) ...[
              VSpace.x2,
              if (accountKeys.isEmpty)
                TerminalText(context.l10n.gitSshNoAccountKeysWarning,
                    role: TextRole.warn)
              else
                _choiceRow<String>(
                  context,
                  value: selectedAccountKeyId ?? accountKeys.first.id,
                  options: accountKeys.map((k) => (k.id, k.label)).toList(),
                  onSelected: (v) => setState(() => selectedAccountKeyId = v),
                ),
            ],
            VSpace.x2,
            Row(children: [
              TerminalCheckbox(
                value:
                    requestedAccess == GitRepositoryAccessRequestedAccess.readWrite,
                onChanged: (checked) => setState(() => requestedAccess = checked
                    ? GitRepositoryAccessRequestedAccess.readWrite
                    : GitRepositoryAccessRequestedAccess.readOnly),
              ),
              HSpace.x2,
              Expanded(
                child: TerminalText(context.l10n.gitSshAllowWriteAccessLabel,
                    role: TextRole.body),
              ),
            ]),
          ],
        ),
        actions: [
          TerminalDialogActions(actions: [
            TerminalActionSpec(context.l10n.actionCancel, ActionKind.refusal,
                () => Navigator.of(dialogContext).pop()),
            TerminalActionSpec(context.l10n.actionAdd, ActionKind.primary,
                () {
              final repository = repositoryController.text.trim();
              final purpose = purposeController.text.trim();
              if (repository.isEmpty || purpose.isEmpty) return;
              final isCustom = provider == GitRepositoryAccessProvider.custom;
              final host = hostController.text.trim();
              final port = int.tryParse(portController.text.trim());
              if (isCustom && host.isEmpty) return;
              final usesExistingAccount = credentialMode ==
                  GitRepositoryAccessCredentialMode.existingAccount;
              if (usesExistingAccount && selectedAccountKeyId == null) return;
              Navigator.of(dialogContext).pop();
              onCreate(
                provider: provider,
                repository: repository,
                purpose: purpose,
                credentialMode: credentialMode,
                requestedAccess: requestedAccess,
                credential: usesExistingAccount ? selectedAccountKeyId : null,
                host: isCustom ? host : null,
                port: isCustom ? port : null,
              );
            }),
          ]),
        ],
      ),
    ),
  );
}

Widget _choiceRow<T>(
  BuildContext context, {
  required T value,
  required List<(T, String)> options,
  required ValueChanged<T> onSelected,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: options
        .map((entry) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(entry.$1),
              child: Row(children: [
                TerminalCheckbox(
                  value: value == entry.$1,
                  onChanged: (_) => onSelected(entry.$1),
                ),
                HSpace.x2,
                Expanded(
                  child: TerminalText(entry.$2, role: TextRole.body),
                ),
              ]),
            ))
        .toList(),
  );
}
