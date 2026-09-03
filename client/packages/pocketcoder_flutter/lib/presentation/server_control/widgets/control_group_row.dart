import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/application/server_control/server_control_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

String _buttonLabel(BuildContext context, ServerControlOperation operation) =>
    switch (operation) {
      ServerControlOperation.restartPocketCoder ||
      ServerControlOperation.restartNixOs =>
        context.l10n.serverControlActionRestart,
      ServerControlOperation.updatePocketCoder ||
      ServerControlOperation.updateNixOs =>
        context.l10n.serverControlActionUpdate,
      ServerControlOperation.saveBackup => context.l10n.serverControlActionSave,
      ServerControlOperation.restoreBackup =>
        context.l10n.serverControlActionRestore,
    };

class ControlGroupRow extends StatelessWidget {
  const ControlGroupRow({
    super.key,
    required this.groupLabel,
    required this.left,
    required this.right,
    required this.disabled,
    required this.onRun,
  });

  final String groupLabel;
  final ServerControlOperation left;
  final ServerControlOperation right;
  final bool disabled;
  final void Function(ServerControlOperation operation) onRun;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: AppSizes.space),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TerminalText(
              groupLabel,
              color: context.colorScheme.primary,
            ),
            VSpace.x1,
            IgnorePointer(
              ignoring: disabled,
              child: Opacity(
                opacity: disabled ? 0.4 : 1,
                child: BiosActionStrip(
                  actions: [
                    BiosActionStripItem(
                      label: _buttonLabel(context, left),
                      emphasis: Emphasis.outlined,
                      onTap: () => onRun(left),
                    ),
                    BiosActionStripItem(
                      label: _buttonLabel(context, right),
                      emphasis: Emphasis.outlined,
                      onTap: () => onRun(right),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
