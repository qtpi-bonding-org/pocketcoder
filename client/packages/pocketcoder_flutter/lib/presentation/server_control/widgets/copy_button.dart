import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';
import 'package:pocketcoder_flutter/design_system/primitives/action_kind.dart';

class CopyButton extends StatelessWidget {
  const CopyButton({super.key, required this.value});

  final String value;

  @override
  Widget build(BuildContext context) => BiosActionButton(
        action: BiosActionStripItem(
          label: context.l10n.serverControlCopy,
          kind: ActionKind.primary,
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.serverControlCopied)),
              );
            }
          },
        ),
      );
}
