import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/server_control/server_control_cubit.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_connection_details_provider.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';
import 'package:pocketcoder_flutter/presentation/server_control/widgets/copy_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

class ConnectionDetails extends StatefulWidget {
  const ConnectionDetails({super.key, required this.details});

  final IServerConnectionDetailsProvider details;

  @override
  State<ConnectionDetails> createState() => ConnectionDetailsState();
}

class ConnectionDetailsState extends State<ConnectionDetails> {
  bool _showPassword = false;

  Future<void> _toggleShowPassword(BuildContext context) async {
    if (_showPassword) {
      setState(() => _showPassword = false);
      return;
    }
    final approved = await context
        .read<ServerControlCubit>()
        .confirmLocalAuth(reason: context.l10n.serverControlLocalAuthReason);
    if (approved && mounted) setState(() => _showPassword = true);
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.details;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TerminalText(context.l10n.serverControlConnectionDetails,
          role: TextRole.body),
      VSpace.x1,
      if (details.ipAddress case final value?)
        DetailRow(
            label: context.l10n.serverControlIpAddress,
            value: value,
            trailing: CopyButton(value: value)),
      if (details.httpsEndpoint case final value?)
        DetailRow(
            label: context.l10n.serverControlHttpsEndpoint,
            value: value,
            trailing: CopyButton(value: value)),
      if (details.adminIdentity case final value?)
        DetailRow(
            label: context.l10n.serverControlAdminIdentity,
            value: value,
            trailing: CopyButton(value: value)),
      if (details.adminPassword case final value?)
        DetailRow(
            label: context.l10n.serverControlAdminPassword,
            value: _showPassword ? value : '•' * value.length,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              BiosActionButton(
                  action: BiosActionStripItem(
                      label: _showPassword
                          ? context.l10n.serverControlHide
                          : context.l10n.serverControlShow,
                      emphasis: Emphasis.outlined,
                      onTap: () => _toggleShowPassword(context))),
              HSpace.x1,
              CopyButton(value: value),
            ])),
    ]);
  }
}
