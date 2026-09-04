import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/server_control/server_control_cubit.dart';
import 'package:pocketcoder_flutter/application/server_control/server_control_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';
import 'package:pocketcoder_flutter/presentation/server_control/widgets/copy_button.dart';

class PrivateKeySection extends StatefulWidget {
  const PrivateKeySection(
      {super.key, required this.instanceId, required this.state});

  final String instanceId;
  final ServerControlState state;

  @override
  State<PrivateKeySection> createState() => PrivateKeySectionState();
}

class PrivateKeySectionState extends State<PrivateKeySection> {
  bool _revealed = false;

  Future<void> _toggleReveal(BuildContext context) async {
    if (_revealed) {
      setState(() => _revealed = false);
      return;
    }
    final cubit = context.read<ServerControlCubit>();
    await cubit.revealPrivateKey(
      instanceId: widget.instanceId,
      authReason: context.l10n.serverControlLocalAuthReason,
    );
    if (mounted && cubit.state.privateKey != null) {
      setState(() => _revealed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final privateKey = widget.state.privateKey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.serverControlPrivateKeyLabel),
        VSpace.x1,
        if (_revealed && privateKey != null)
          Row(
            children: [
              Expanded(child: SelectableText(privateKey)),
              CopyButton(value: privateKey),
            ],
          )
        else
          const SizedBox.shrink(),
        VSpace.x1,
        BiosActionButton(
          action: BiosActionStripItem(
            label: _revealed
                ? context.l10n.serverControlHide
                : context.l10n.serverControlShow,
            emphasis: Emphasis.outlined,
            onTap: () => _toggleReveal(context),
          ),
        ),
      ],
    );
  }
}
