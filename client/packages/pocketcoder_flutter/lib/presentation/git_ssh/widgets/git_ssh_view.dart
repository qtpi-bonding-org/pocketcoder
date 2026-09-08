import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/application/git_ssh/git_ssh_state.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/git_repository_access.dart';
import 'package:pocketcoder_flutter/domain/models/git_ssh_credential.dart';
import 'package:pocketcoder_flutter/presentation/core/safe_error_message.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/section_header.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_spinner.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

import 'git_ssh_dialogs.dart';

class GitSshView extends StatelessWidget {
  const GitSshView({
    super.key,
    required this.state,
    required this.onCreateAccountKey,
    required this.onAddRepositoryAccess,
    required this.onDeleteAccess,
  });

  final GitSshState state;
  final Future<void> Function(String label) onCreateAccountKey;
  final Future<void> Function({
    required GitRepositoryAccessProvider provider,
    required String repository,
    required String purpose,
    required GitRepositoryAccessCredentialMode credentialMode,
    required GitRepositoryAccessRequestedAccess requestedAccess,
    String? credential,
    String? host,
    int? port,
  }) onAddRepositoryAccess;
  final Future<void> Function(String accessId) onDeleteAccess;

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      footer: buildPillarFooter(context, NavPillar.config),
      showBack: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(name: context.l10n.gitSshScreenTitle.toLowerCase()),
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
              return ListView(children: [
                SectionHeader(
                    name: context.l10n.gitSshAccountKeysHeader.toLowerCase()),
                Padding(
                  padding: EdgeInsets.all(AppSizes.space),
                  child: TerminalButton(
                    label: context.l10n.gitSshAddAccountKeyButton,
                    onTap: () =>
                        showAddAccountKeyDialog(context, onCreateAccountKey),
                  ),
                ),
                for (final credential in state.credentials)
                  _credentialItem(context, credential),
                VSpace.x2,
                SectionHeader(
                    name: context.l10n.gitSshRepositoriesHeader.toLowerCase()),
                Padding(
                  padding: EdgeInsets.all(AppSizes.space),
                  child: TerminalButton(
                    label: context.l10n.gitSshAddRepositoryAccessButton,
                    onTap: () => showAddRepositoryAccessDialog(
                      context,
                      accountKeys: state.credentials
                          .where((c) =>
                              c.kind == GitSshCredentialKind.account &&
                              c.status == GitSshCredentialStatus.ready)
                          .toList(),
                      onCreate: onAddRepositoryAccess,
                    ),
                  ),
                ),
                for (final access in state.access)
                  _accessItem(context, access),
                if (state.credentials.isEmpty && state.access.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSizes.space * 4),
                      child: TerminalText(context.l10n.gitSshEmptyState,
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

  Widget _credentialItem(BuildContext context, GitSshCredential credential) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DetailRow(label: credential.label, value: credential.status.name),
      if (credential.status == GitSshCredentialStatus.error &&
          (credential.lastError ?? '').isNotEmpty)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.space),
          child:
              TerminalText(credential.lastError ?? '', role: TextRole.warn),
        ),
      VSpace.x1,
      if (credential.status == GitSshCredentialStatus.ready &&
          (credential.publicKey ?? '').isNotEmpty)
        BiosActionStrip(actions: [
          BiosActionStripItem(
            label: context.l10n.gitSshShowPublicKeyButton,
            onTap: () => showPublicKeyDialog(
              context,
              label: credential.label,
              publicKey: credential.publicKey ?? '',
            ),
          ),
        ]),
      VSpace.x2,
    ]);
  }

  Widget _accessItem(BuildContext context, GitRepositoryAccess access) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DetailRow(
          label: '${access.provider.name}/${access.repository}',
          value: access.status.name,
          warning: access.status == GitRepositoryAccessStatus.pending ||
              access.status == GitRepositoryAccessStatus.error),
      if (access.status == GitRepositoryAccessStatus.error &&
          (access.lastError ?? '').isNotEmpty)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.space),
          child: TerminalText(access.lastError ?? '', role: TextRole.warn),
        ),
      VSpace.x1,
      BiosActionStrip(actions: [
        BiosActionStripItem(
          label: context.l10n.gitSshRemoveAccessButton,
          kind: ActionKind.destructive,
          onTap: () => onDeleteAccess(access.id),
        ),
      ]),
      VSpace.x2,
    ]);
  }
}
