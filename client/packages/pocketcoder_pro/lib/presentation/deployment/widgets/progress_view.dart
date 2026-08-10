import 'package:flutter/material.dart';
import 'package:flutter_aeroform/domain/models/instance.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_pro/domain/deployment/onboarding_stage.dart';
import 'package:pocketcoder_pro/domain/deployment/server_status_document.dart';

/// Pure presentation widget for the deployment progress screen.
class ProgressView extends StatelessWidget {
  const ProgressView({
    super.key,
    required this.status,
    required this.deploymentStatus,
    required this.pollingAttempts,
    required this.serverStatusDocument,
    required this.provisioningTour,
    required this.instance,
    required this.error,
    required this.onAbort,
    required this.onRetry,
  });

  final UiFlowStatus status;
  final OnboardingStage? deploymentStatus;
  final int pollingAttempts;
  final ServerStatusDocument? serverStatusDocument;
  final Widget provisioningTour;
  final Instance? instance;
  final Object? error;
  final VoidCallback onAbort;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final currentInstance = instance;
    final currentServerStatus = serverStatusDocument;
    final retry = onRetry;

    return TerminalScaffold(
      title: 'DEPLOYMENT IN PROGRESS',
      actions: [
        TerminalAction(label: 'ABORT', onTap: onAbort),
        if (status == UiFlowStatus.failure && retry != null)
          TerminalAction(label: 'RETRY SCAN', onTap: retry),
      ],
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: AppSizes.space),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                BiosFrame(
                  title: 'TELEMETRY STREAM',
                  child: Padding(
                    padding: EdgeInsets.all(AppSizes.space * 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStatusIndicator(deploymentStatus),
                        VSpace.x3,
                        Text(
                          _getStatusTitle(deploymentStatus),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppFonts.headerFamily,
                            color: _getStatusColor(deploymentStatus, colors),
                            fontSize: AppSizes.fontBig,
                            fontWeight: AppFonts.heavy,
                          ),
                        ),
                        VSpace.x2,
                        Text(
                          _getStatusDescription(deploymentStatus),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppFonts.bodyFamily,
                            color: colors.onSurface.withValues(alpha: 0.7),
                            fontSize: AppSizes.fontSmall,
                          ),
                        ),
                        VSpace.x4,
                        if (pollingAttempts > 0) ...[
                          Text(
                            context.l10n.deploymentSyncAttempt(pollingAttempts),
                            style: TextStyle(
                              fontFamily: AppFonts.bodyFamily,
                              color: colors.primary,
                              fontSize: AppSizes.fontTiny,
                            ),
                          ),
                          VSpace.x1,
                        ],
                        if (status == UiFlowStatus.loading)
                          _buildProgressBar(colors),
                        VSpace.x4,
                        if (currentServerStatus?.detail?.isNotEmpty ??
                            false) ...[
                          _buildInfoRow(
                            context.l10n.deploymentCurrentOperation,
                            currentServerStatus?.detail ?? '',
                            colors,
                          ),
                          VSpace.x1,
                        ],
                        if (currentServerStatus != null) ...[
                          _buildInfoRow(
                            context.l10n.deploymentSourceCommit,
                            currentServerStatus.sourceCommit ?? 'UNKNOWN',
                            colors,
                          ),
                          VSpace.x1,
                          _buildInfoRow(
                            context.l10n.deploymentRunId,
                            currentServerStatus.runId,
                            colors,
                          ),
                          VSpace.x1,
                          _buildInfoRow(
                            context.l10n.deploymentStatusSchema,
                            currentServerStatus.schema.toString(),
                            colors,
                          ),
                          VSpace.x1,
                          _buildInfoRow(
                            context.l10n.deploymentLastSignal,
                            currentServerStatus.updatedAt
                                .toUtc()
                                .toIso8601String(),
                            colors,
                          ),
                          if (currentServerStatus.error?.isNotEmpty ??
                              false) ...[
                            VSpace.x1,
                            _buildInfoRow(
                              context.l10n.deploymentErrorCode,
                              currentServerStatus.error ?? '',
                              colors,
                            ),
                          ],
                          VSpace.x2,
                        ],
                        if (currentInstance != null) ...[
                          _buildInfoRow(
                              'NETWORK IP', currentInstance.ipAddress, colors),
                          VSpace.x1,
                          _buildInfoRow(
                              'GEO GRID', currentInstance.region, colors),
                        ],
                        if (status == UiFlowStatus.failure) ...[
                          VSpace.x4,
                          Container(
                            padding: EdgeInsets.all(AppSizes.space),
                            decoration: BoxDecoration(
                              border: Border.all(color: colors.error),
                              color: colors.error.withValues(alpha: 0.1),
                            ),
                            child: Text(
                              'FAULT DETECTED: ${error.toString().toUpperCase()}',
                              style: TextStyle(
                                color: colors.error,
                                fontFamily: AppFonts.bodyFamily,
                                fontSize: AppSizes.fontTiny,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                VSpace.x3,
                provisioningTour,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(OnboardingStage? status) {
    if (status == OnboardingStage.ready) {
      return const Icon(Icons.check_circle_outline,
          color: Colors.green, size: 48);
    }
    return const TerminalLoadingIndicator(label: '');
  }

  Widget _buildProgressBar(ColorScheme colors) {
    return LinearProgressIndicator(
      minHeight: 4,
      color: colors.primary,
      backgroundColor: colors.primary.withValues(alpha: 0.1),
    );
  }

  String _getStatusTitle(OnboardingStage? status) {
    switch (status) {
      case OnboardingStage.validating:
        return 'VALIDATING CONFIGURATION';
      case OnboardingStage.creatingServer:
        return 'CONSTRUCTING INSTANCE';
      case OnboardingStage.preparingHost:
      case OnboardingStage.hostReady:
        return 'PREPARING HOST';
      case OnboardingStage.securingConnection:
        return 'SECURING CONNECTION';
      case OnboardingStage.installingHost:
        return 'INSTALLING HOST';
      case OnboardingStage.fetchingRelease:
        return 'FETCHING RELEASE';
      case OnboardingStage.loadingImages:
        return 'LOADING IMAGES';
      case OnboardingStage.startingServices:
        return 'STARTING SERVICES';
      case OnboardingStage.finishingUp:
        return 'FINISHING UP';
      case OnboardingStage.ready:
        return 'HANDSHAKE SUCCESSFUL';
      case OnboardingStage.failed:
        return 'DEPLOYMENT ABORTED';
      case null:
        return 'INITIALIZING STACK';
    }
  }

  String _getStatusDescription(OnboardingStage? status) {
    switch (status) {
      case OnboardingStage.validating:
        return 'CHECKING THE PROVISIONING CONFIGURATION.';
      case OnboardingStage.creatingServer:
        return 'ALLOCATING HARDWARE RESOURCES ON CLOUD GRID.';
      case OnboardingStage.preparingHost:
      case OnboardingStage.hostReady:
        return 'INSTALLING THE CONTAINER HOST.';
      case OnboardingStage.securingConnection:
        return 'WAITING FOR THE NATIVE REVERSE PROXY.';
      case OnboardingStage.installingHost:
        return 'INSTALLING THE APPLICATION HOST.';
      case OnboardingStage.fetchingRelease:
        return 'FETCHING THE IMMUTABLE RELEASE.';
      case OnboardingStage.loadingImages:
        return 'LOADING THE VERIFIED IMAGE BUNDLE.';
      case OnboardingStage.startingServices:
        return 'STARTING APPLICATION SERVICES.';
      case OnboardingStage.finishingUp:
        return 'FINISHING DEPLOYMENT.';
      case OnboardingStage.ready:
        return 'THE SERVER IS FULLY OPERATIONAL.';
      case OnboardingStage.failed:
        return 'CRITICAL FAILURE DURING RESOURCE ALLOCATION.';
      case null:
        return 'PREPARING DEPLOYMENT MANIFEST.';
    }
  }

  Color _getStatusColor(OnboardingStage? status, ColorScheme colors) {
    if (status == OnboardingStage.ready) return Colors.green;
    if (status == OnboardingStage.failed) return colors.error;
    return colors.primary;
  }

  Widget _buildInfoRow(String label, String value, ColorScheme colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.bodyFamily,
              color: colors.onSurface.withValues(alpha: 0.5),
              fontSize: AppSizes.fontTiny,
            ),
          ),
        ),
        HSpace.x2,
        Expanded(
          flex: 2,
          child: Text(
            value.toUpperCase(),
            textAlign: TextAlign.end,
            style: TextStyle(
              fontFamily: AppFonts.bodyFamily,
              color: colors.onSurface,
              fontSize: AppSizes.fontTiny,
              fontWeight: AppFonts.heavy,
            ),
          ),
        ),
      ],
    );
  }
}
