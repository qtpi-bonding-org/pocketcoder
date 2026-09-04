import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_provider_console_link.dart';
import 'package:pocketcoder_flutter/presentation/core/in_app_browser_launcher.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';

class ProviderConsoleButton extends StatelessWidget {
  const ProviderConsoleButton(
      {super.key, required this.link, required this.launcher});

  final IProviderConsoleLink link;
  final InAppBrowserLauncher launcher;

  @override
  Widget build(BuildContext context) => BiosActionStrip(
        actions: [
          BiosActionStripItem(
            label: context.l10n.serverControlProviderConsole,
            emphasis: Emphasis.outlined,
            onTap: () async {
              final uri = await link.resolve();
              if (!context.mounted) return;
              if (uri == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        context.l10n.serverControlProviderConsoleUnavailable),
                  ),
                );
                return;
              }
              await launcher.open(uri);
            },
          ),
        ],
      );
}
