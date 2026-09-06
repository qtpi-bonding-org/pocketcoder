import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/application/server_control/server_control_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class ReleaseLine extends StatelessWidget {
  const ReleaseLine({super.key, required this.state});

  final ServerControlState state;

  @override
  Widget build(BuildContext context) {
    final release = state.release;
    return TerminalText(
      release == null
          ? context.l10n.serverControlReleaseChecking
          : _lines(context, release),
      role: TextRole.body,
    );
  }

  String _lines(BuildContext context, ServerReleaseStatusSnapshot release) {
    final lines = [
      context.l10n
          .serverControlReleaseStatus(release.status.name),
      context.l10n.serverControlReleaseCurrent(release.currentVersion),
      if (release.availableVersion case final available?)
        context.l10n.serverControlReleaseAvailable(available),
      if (release.appContractVersion case final app?)
        if (release.serverApiVersion case final server?)
          if (release.deploymentContractVersion case final deployment?)
            context.l10n.serverControlReleaseContracts(
                app.toString(), server.toString(), deployment.toString()),
      if (release.nixosVersion case final nixos?)
        context.l10n.serverControlReleaseNixos(nixos),
    ];
    return lines.join('\n');
  }
}
