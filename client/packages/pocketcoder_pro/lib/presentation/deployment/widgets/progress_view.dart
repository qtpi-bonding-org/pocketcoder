import 'package:flutter/material.dart';
import 'package:flutter_aeroform/domain/models/instance.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_pro/domain/deployment/onboarding_stage.dart';
import 'package:pocketcoder_pro/domain/deployment/server_status_document.dart';
import 'package:pocketcoder_pro/presentation/deployment/widgets/pocketcoder_progress_pane.dart';

/// Pure presentation widget for the deployment progress screen.
class ProgressView extends StatelessWidget {
  const ProgressView({
    super.key,
    required this.status,
    required this.deploymentStatus,
    required this.pollingAttempts,
    required this.serverStatusDocument,
    required this.progressPane,
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
  final PocketCoderProgressPane progressPane;
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
      title: context.l10n.deploymentScreenTitle,
      actions: [
        TerminalAction(
            label: context.l10n.deploymentActionAbort, onTap: onAbort),
        if (status == UiFlowStatus.failure && retry != null)
          TerminalAction(
              label: context.l10n.deploymentActionRetryScan, onTap: retry),
      ],
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: AppSizes.space),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                progressPane,
                VSpace.x3,
                Padding(
                  padding: EdgeInsets.all(AppSizes.space * 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getStatusTitle(context, deploymentStatus),
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
                        _getStatusDescription(context, deploymentStatus),
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
                      VSpace.x4,
                      if (currentServerStatus?.detail?.isNotEmpty ?? false) ...[
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
                          currentServerStatus.sourceCommit ??
                              context.l10n.deploymentUnknown,
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
                        if (currentServerStatus.error?.isNotEmpty ?? false) ...[
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
                        _buildInfoRow(context.l10n.deploymentNetworkIp,
                            currentInstance.ipAddress, colors),
                        VSpace.x1,
                        _buildInfoRow(context.l10n.deploymentGeoGrid,
                            currentInstance.region, colors),
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
                            context.l10n.deploymentFaultDetected(
                                error.toString().toUpperCase()),
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
                VSpace.x3,
                provisioningTour,
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getStatusTitle(BuildContext context, OnboardingStage? status) {
    switch (status) {
      case OnboardingStage.validating:
        return context.l10n.deploymentStatusValidating;
      case OnboardingStage.creatingServer:
        return context.l10n.deploymentStatusConstructing;
      case OnboardingStage.preparingHost:
      case OnboardingStage.hostReady:
        return context.l10n.deploymentStatusPreparingHost;
      case OnboardingStage.securingConnection:
        return context.l10n.deploymentStatusSecuring;
      case OnboardingStage.installingHost:
        return context.l10n.deploymentStatusInstalling;
      case OnboardingStage.fetchingRelease:
        return context.l10n.deploymentStatusFetching;
      case OnboardingStage.loadingImages:
        return context.l10n.deploymentStatusLoadingImages;
      case OnboardingStage.startingServices:
        return context.l10n.deploymentStatusStarting;
      case OnboardingStage.finishingUp:
        return context.l10n.deploymentStatusFinishing;
      case OnboardingStage.ready:
        return context.l10n.deploymentStatusReady;
      case OnboardingStage.failed:
        return context.l10n.deploymentStatusFailed;
      case null:
        return context.l10n.deploymentStatusInitializing;
    }
  }

  String _getStatusDescription(BuildContext context, OnboardingStage? status) {
    switch (status) {
      case OnboardingStage.validating:
        return context.l10n.deploymentDescriptionValidating;
      case OnboardingStage.creatingServer:
        return context.l10n.deploymentDescriptionConstructing;
      case OnboardingStage.preparingHost:
      case OnboardingStage.hostReady:
        return context.l10n.deploymentDescriptionPreparingHost;
      case OnboardingStage.securingConnection:
        return context.l10n.deploymentDescriptionSecuring;
      case OnboardingStage.installingHost:
        return context.l10n.deploymentDescriptionInstalling;
      case OnboardingStage.fetchingRelease:
        return context.l10n.deploymentDescriptionFetching;
      case OnboardingStage.loadingImages:
        return context.l10n.deploymentDescriptionLoadingImages;
      case OnboardingStage.startingServices:
        return context.l10n.deploymentDescriptionStarting;
      case OnboardingStage.finishingUp:
        return context.l10n.deploymentDescriptionFinishing;
      case OnboardingStage.ready:
        return context.l10n.deploymentDescriptionReady;
      case OnboardingStage.failed:
        return context.l10n.deploymentDescriptionFailed;
      case null:
        return context.l10n.deploymentDescriptionInitializing;
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
