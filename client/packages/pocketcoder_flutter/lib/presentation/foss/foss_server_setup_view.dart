import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/foss/foss_server_setup_cubit.dart';
import 'package:pocketcoder_flutter/application/foss/foss_server_setup_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';

class FossServerSetupView extends StatelessWidget {
  const FossServerSetupView({super.key, required this.onSetupComplete});

  final VoidCallback onSetupComplete;

  @override
  Widget build(BuildContext context) => BlocConsumer<FossServerSetupCubit,
          FossServerSetupState>(
      listenWhen: (previous, current) =>
          previous.phase != FossServerSetupPhase.connected &&
          current.phase == FossServerSetupPhase.connected,
      listener: (context, state) => onSetupComplete(),
      builder: (context, state) => Material(
              child: ListView(
                  padding: EdgeInsets.all(AppSizes.space * 2),
                  children: [
                TerminalText(
                  context.l10n.fossServerSetupTitle,
                  role: TextRole.label,
                ),
                VSpace.x1,
                Text(context.l10n.fossServerSetupIntro),
                VSpace.x2,
                if (state.phase == FossServerSetupPhase.idle)
                  TerminalButton(
                      label: context.l10n.fossServerSetupGenerateKey,
                      kind: ActionKind.primary,
                      onTap: () =>
                          context.read<FossServerSetupCubit>().generateKey()),
                if (state.publicKey case final publicKey?) ...[
                  Text(context.l10n.fossServerSetupPublicKeyLabel),
                  VSpace.x1,
                  Row(children: [
                    Expanded(child: SelectableText(publicKey)),
                    IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: publicKey))),
                  ]),
                  VSpace.x2,
                  Text('${context.l10n.fossServerSetupHostLabel} '
                      '${context.read<FossServerSetupCubit>().host}'),
                  VSpace.x2,
                  if (state.phase != FossServerSetupPhase.connected)
                    TerminalButton(
                        label: context.l10n.fossServerSetupTestAndSave,
                        kind: ActionKind.primary,
                        isLoading: state.phase == FossServerSetupPhase.testing,
                        onTap: () =>
                            context.read<FossServerSetupCubit>().testAndSave()),
                ],
                if (state.error case final error?) ...[
                  VSpace.x1,
                  TerminalText(context.l10n.fossServerSetupErrorPrefix(error),
                      role: TextRole.warn),
                ],
                if (state.phase == FossServerSetupPhase.connected) ...[
                  VSpace.x2,
                  Text(context.l10n.fossServerSetupConnected),
                ],
              ])));
}
