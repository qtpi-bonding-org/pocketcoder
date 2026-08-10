import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_pro/domain/server_update/server_update_result.dart';

/// Pure presentation widget for the server update screen.
class UpdateServerView extends StatelessWidget {
  const UpdateServerView({
    super.key,
    required this.isLoading,
    required this.result,
    required this.onUpdate,
    required this.onDismiss,
  });

  final bool isLoading;
  final ServerUpdateResult? result;
  final VoidCallback onUpdate;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;

    return TerminalScaffold(
      title: 'SERVER UPDATE',
      actions: [TerminalAction(label: 'DISMISS', onTap: onDismiss)],
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: AppSizes.space),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BiosFrame(
              title: 'UPDATE SEQUENCE',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VERIFY RELEASE → DOWNLOAD PREBUILT IMAGES → '
                    'REPLACE MANAGED CONTAINERS',
                    style: TextStyle(
                      fontFamily: AppFonts.bodyFamily,
                      color: colors.onSurface.withValues(alpha: 0.7),
                      fontSize: AppSizes.fontSmall,
                    ),
                  ),
                  VSpace.x1,
                  Text(
                    'YOUR WORKSPACES, AUTH DATA, AND SERVER CONFIGURATION ARE PRESERVED. '
                    'NOTHING HAPPENS UNTIL YOU TAP UPDATE.',
                    style: TextStyle(
                      fontFamily: AppFonts.bodyFamily,
                      color: colors.onSurface.withValues(alpha: 0.5),
                      fontSize: AppSizes.fontTiny,
                    ),
                  ),
                ],
              ),
            ),
            VSpace.x2,
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : onUpdate,
                child: Text(isLoading ? 'UPDATING...' : 'UPDATE'),
              ),
            ),
            if (result != null) ...[
              VSpace.x2,
              _ResultBanner(result: result!, colors: colors),
              VSpace.x2,
              BiosFrame(
                title: 'OUTPUT',
                child: SelectableText(
                  _combinedOutput(result!),
                  style: TextStyle(
                    fontFamily: AppFonts.bodyFamily,
                    color: colors.onSurface,
                    fontSize: AppSizes.fontTiny,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _combinedOutput(ServerUpdateResult value) {
    if (value.stderr.isEmpty) return value.stdout;
    return '${value.stdout}\n--- stderr ---\n${value.stderr}';
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result, required this.colors});

  final ServerUpdateResult result;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final color = result.succeeded ? colors.primary : colors.error;
    return Container(
      padding: EdgeInsets.all(AppSizes.space),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
      ),
      child: Text(
        result.succeeded
            ? 'UPDATE SUCCEEDED (EXIT 0)'
            : 'UPDATE FAILED (EXIT ${result.exitCode})',
        style: TextStyle(
          fontFamily: AppFonts.bodyFamily,
          color: color,
          fontWeight: AppFonts.heavy,
          fontSize: AppSizes.fontStandard,
        ),
      ),
    );
  }
}
