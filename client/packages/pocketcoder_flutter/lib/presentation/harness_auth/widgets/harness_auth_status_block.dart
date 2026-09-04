import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/presentation/core/widgets/section_header.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class HarnessAuthStatusBlock extends StatelessWidget {
  const HarnessAuthStatusBlock(
      {super.key,
      required this.harness,
      required this.status,
      required this.configuredApiKeyProvider,
      required this.child});

  final Harnesse harness;
  final HarnessAuthStatus? status;
  final domain.Provider? configuredApiKeyProvider;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = status ??
        HarnessAuthStatus(
            harness: harness.id,
            provider: '',
            accountId: '',
            accountName: '',
            visibility: harnessAccountVisibilityPersonal,
            credentialMode: 'none',
            status: 'disconnected');
    return Column(children: [
      SectionHeader(name: '${harness.name} [${harness.cliId}]'.toLowerCase()),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TerminalText(l10n.harnessAuthStatus(s.status.toUpperCase()),
            role: TextRole.body),
        if (s.lastError case final lastError? when lastError.isNotEmpty) ...[
          VSpace.x1,
          TerminalText(lastError, role: TextRole.warn),
        ],
        if (s.credentialMode.isNotEmpty) ...[
          VSpace.x1,
          TerminalText(
            l10n.harnessAuthMode(s.credentialMode.toUpperCase()),
            role: TextRole.body,
          ),
        ],
        if (s.accountId.isNotEmpty) ...[
          VSpace.x1,
          TerminalText(
            l10n.harnessAuthAccount(
              s.accountName.isEmpty ? s.accountId : s.accountName,
              s.isDeploymentVisible
                  ? l10n.harnessAuthShared
                  : l10n.harnessAuthPersonal,
            ),
            role: TextRole.body,
          ),
        ],
        if (configuredApiKeyProvider case final provider?) ...[
          VSpace.x1,
          TerminalText(
            l10n.harnessAuthApiKeyConfigured(provider.name.toUpperCase()),
            role: TextRole.body,
          ),
        ],
        VSpace.x2,
        child,
      ]),
    ]);
  }
}
