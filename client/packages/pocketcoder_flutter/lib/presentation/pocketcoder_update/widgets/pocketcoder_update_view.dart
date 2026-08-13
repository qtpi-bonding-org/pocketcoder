import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/chat/widgets/terminal_command_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_status_glyph.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_flutter/domain/pocketcoder_update/pocketcoder_update_result.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';

/// Pure presentation widget for the PocketCoder update screen.
class PocketCoderUpdateView extends StatelessWidget {
  const PocketCoderUpdateView({
    super.key,
    required this.isLoading,
    required this.preview,
    required this.result,
    required this.upgradeConfirmed,
    required this.onRefresh,
    required this.onUpdate,
    required this.onDismiss,
  });

  final bool isLoading;
  final ServerReleaseStatusSnapshot? preview;
  final PocketCoderUpdateResult? result;
  final bool upgradeConfirmed;
  final VoidCallback onRefresh;
  final VoidCallback onUpdate;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final canUpgrade = preview?.status == ServerReleaseStatus.updateAvailable ||
        preview?.status == ServerReleaseStatus.criticalReleaseWarning;

    return TerminalScaffold(
      title: context.l10n.pocketCoderUpdateTitle,
      actions: [
        TerminalAction(
          label: context.l10n.actionDismiss,
          onTap: onDismiss,
        ),
      ],
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: AppSizes.space),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReleasePreview(preview: preview, colors: colors),
            VSpace.x2,
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading || !canUpgrade ? null : onUpdate,
                child: Text(_actionLabel(context)),
              ),
            ),
            VSpace.x1,
            TextButton(
              onPressed: isLoading ? null : onRefresh,
              child: Text(context.l10n.pocketCoderUpdateCheckAgain),
            ),
            if (result case final updateResult?) ...[
              VSpace.x2,
              _ResultBanner(result: updateResult, colors: colors),
              VSpace.x2,
              TerminalCommandCard(
                command: context.l10n.pocketCoderUpdateCommand,
                status: updateResult.succeeded
                    ? TerminalStatus.success
                    : TerminalStatus.failure,
                outputLabel: context.l10n.pocketCoderUpdateOutput,
                output: _combinedOutput(context, updateResult),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _actionLabel(BuildContext context) {
    if (isLoading) return context.l10n.pocketCoderUpdateWorking;
    if (preview?.crossesDataVersion == true && !upgradeConfirmed) {
      return context.l10n.pocketCoderUpdateReviewDataChange;
    }
    if (preview?.crossesDataVersion == true) {
      return context.l10n.pocketCoderUpdateConfirmUpgrade;
    }
    return context.l10n.pocketCoderUpdateUpgrade;
  }

  String _combinedOutput(
    BuildContext context,
    PocketCoderUpdateResult value,
  ) {
    if (value.stderr.isEmpty) return value.stdout;
    return '${value.stdout}\n${context.l10n.pocketCoderUpdateStderr}\n'
        '${value.stderr}';
  }
}

class _ReleasePreview extends StatelessWidget {
  const _ReleasePreview({required this.preview, required this.colors});

  final ServerReleaseStatusSnapshot? preview;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final value = preview;
    if (value == null) {
      return Text(
        context.l10n.pocketCoderUpdateChecking,
        style: _textStyle(colors.onSurface),
      );
    }
    final critical = value.status == ServerReleaseStatus.criticalReleaseWarning;
    final statusColor = critical ? colors.error : colors.primary;
    return Container(
      padding: EdgeInsets.all(AppSizes.space),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: statusColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_statusLabel(context, value), style: _textStyle(statusColor)),
          VSpace.x1,
          _line(
            context,
            context.l10n.pocketCoderUpdateCurrent,
            value.currentVersion,
          ),
          if (value.availableVersion case final availableVersion?)
            _line(
              context,
              context.l10n.pocketCoderUpdateAvailable,
              availableVersion,
            ),
          if (value.downloadBytes case final downloadBytes?)
            _line(
              context,
              context.l10n.pocketCoderUpdateDownload,
              _formatBytes(downloadBytes),
            ),
          if (value.requiredDiskBytes case final requiredDiskBytes?)
            _line(
              context,
              context.l10n.pocketCoderUpdateRequiredDisk,
              _formatBytes(requiredDiskBytes),
            ),
          if (value.crossesDataVersion) ...[
            VSpace.x1,
            Text(
              context.l10n.pocketCoderUpdateDataBoundary(
                value.currentDataVersion,
                value.availableDataVersion ?? value.currentDataVersion,
              ),
              style: _textStyle(colors.error),
            ),
            VSpace.x1,
            Text(
              context.l10n.pocketCoderUpdateRollbackWarning,
              style: _textStyle(colors.onSurface.withValues(alpha: 0.7)),
            ),
          ],
          if (value.summary case final summary?) ...[
            VSpace.x1,
            Text(summary, style: _textStyle(statusColor)),
          ],
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value) => Padding(
        padding: EdgeInsets.only(bottom: AppSizes.space / 2),
        child: Text('$label: $value', style: _textStyle(colors.onSurface)),
      );

  String _statusLabel(
    BuildContext context,
    ServerReleaseStatusSnapshot value,
  ) =>
      switch (value.status) {
        ServerReleaseStatus.current =>
          context.l10n.pocketCoderUpdateCurrentStatus,
        ServerReleaseStatus.updateAvailable =>
          context.l10n.pocketCoderUpdateAvailableStatus,
        ServerReleaseStatus.criticalReleaseWarning =>
          context.l10n.pocketCoderUpdateCriticalStatus,
        ServerReleaseStatus.unknown =>
          context.l10n.pocketCoderUpdateUnknownStatus,
      };

  TextStyle _textStyle(Color color) => TextStyle(
        fontFamily: AppFonts.bodyFamily,
        color: color,
        fontSize: AppSizes.fontSmall,
      );

  String _formatBytes(int bytes) {
    const bytesPerMiB = 1024 * 1024;
    const bytesPerGiB = bytesPerMiB * 1024;
    if (bytes >= bytesPerGiB) {
      return '${(bytes / bytesPerGiB).toStringAsFixed(1)} GiB';
    }
    return '${(bytes / bytesPerMiB).ceil()} MiB';
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result, required this.colors});

  final PocketCoderUpdateResult result;
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
            ? context.l10n.pocketCoderUpdateSucceeded
            : context.l10n.pocketCoderUpdateFailed(result.exitCode),
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
