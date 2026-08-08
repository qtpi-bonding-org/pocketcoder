import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_cubit.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_message_mapper.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_state.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_pro/domain/deployment/onboarding_stage.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:get_it/get_it.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

/// Progress screen showing deployment status
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return UiFlowListener<DeploymentCubit, DeploymentState>(
      mapper: GetIt.I<DeploymentMessageMapper>(),
      child: const _ProgressView(),
    );
  }
}

class _ProgressView extends StatefulWidget {
  const _ProgressView();

  @override
  State<_ProgressView> createState() => _ProgressViewState();
}

class _ProgressViewState extends State<_ProgressView> {
  @override
  void initState() {
    super.initState();
    // Start monitoring deployment if not already started
    final cubit = context.read<DeploymentCubit>();
    final state = cubit.state;
    if (state.instanceId != null && state.hostname != null && !cubit.isMonitoring) {
      cubit.monitorDeployment(
        hostname: state.hostname ?? '',
        instanceId: state.instanceId ?? '',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final cubit = context.read<DeploymentCubit>();

    return BlocListener<DeploymentCubit, DeploymentState>(
      listener: (context, state) {
        if (state.instanceId != null &&
            !cubit.isMonitoring &&
            state.deploymentStatus != OnboardingStage.ready &&
            state.deploymentStatus != OnboardingStage.failed) {
          if (state.hostname != null) {
            cubit.monitorDeployment(
              hostname: state.hostname ?? '',
              instanceId: state.instanceId ?? '',
            );
          }
        }
        // Navigate to DetailsScreen on deployment completion
        if (state.status == UiFlowStatus.success &&
            state.deploymentStatus == OnboardingStage.ready &&
            state.instance != null) {
          context.pushNamed(
            RouteNames.deploymentDetails,
            queryParameters: {'instanceId': state.instance?.id ?? ''},
          );
        }
      },
      child: BlocBuilder<DeploymentCubit, DeploymentState>(
        builder: (context, state) {
          return TerminalScaffold(
            title: 'DEPLOYMENT IN PROGRESS',
            actions: [
              TerminalAction(
                label: 'ABORT',
                onTap: () {
                  cubit.cancelDeployment();
                  context.pop();
                },
              ),
              if (state.status == UiFlowStatus.failure)
                TerminalAction(
                  label: 'RETRY SCAN',
                  onTap: () {
                    if (state.instanceId != null) {
                      context
                          .read<DeploymentCubit>()
                          .monitorDeployment(
                            hostname: state.hostname ?? '',
                            instanceId: state.instanceId ?? '',
                          );
                    }
                  },
                ),
            ],
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: BiosFrame(
                  title: 'TELEMETRY STREAM',
                  child: Padding(
                    padding: EdgeInsets.all(AppSizes.space * 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStatusIndicator(state.deploymentStatus),
                        VSpace.x3,
                        Text(
                          _getStatusTitle(state.deploymentStatus),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppFonts.headerFamily,
                            color:
                                _getStatusColor(state.deploymentStatus, colors),
                            fontSize: AppSizes.fontBig,
                            fontWeight: AppFonts.heavy,
                          ),
                        ),
                        VSpace.x2,
                        Text(
                          _getStatusDescription(state.deploymentStatus),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppFonts.bodyFamily,
                            color: colors.onSurface.withValues(alpha: 0.7),
                            fontSize: AppSizes.fontSmall,
                          ),
                        ),
                        VSpace.x4,
                        if (state.pollingAttempts > 0) ...[
                          Text(
                            'SYNC ATTEMPT: ${state.pollingAttempts} / 20',
                            style: TextStyle(
                              fontFamily: AppFonts.bodyFamily,
                              color: colors.primary,
                              fontSize: AppSizes.fontTiny,
                            ),
                          ),
                          VSpace.x1,
                        ],
                        if (state.status == UiFlowStatus.loading)
                          _buildProgressBar(state.pollingAttempts, colors),
                        VSpace.x4,
                        if (state.instance != null) ...[
                          _buildInfoRow(
                              'NETWORK IP', state.instance!.ipAddress, colors),
                          VSpace.x1,
                          _buildInfoRow(
                              'GEO GRID', state.instance!.region, colors),
                        ],
                        if (state.status == UiFlowStatus.failure) ...[
                          VSpace.x4,
                          Container(
                            padding: EdgeInsets.all(AppSizes.space),
                            decoration: BoxDecoration(
                              border: Border.all(color: colors.error),
                              color: colors.error.withValues(alpha: 0.1),
                            ),
                            child: Text(
                              'FAULT DETECTED: ${state.error.toString().toUpperCase()}',
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
              ),
            ),
          );
        },
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

  Widget _buildProgressBar(int attempts, ColorScheme colors) {
    final progress = (attempts / 20).clamp(0.0, 1.0);
    return Container(
      height: 4,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress == 0 ? 0.05 : progress,
        child: Container(color: colors.primary),
      ),
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            color: colors.onSurface.withValues(alpha: 0.5),
            fontSize: AppSizes.fontTiny,
          ),
        ),
        Text(
          value.toUpperCase(),
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            color: colors.onSurface,
            fontSize: AppSizes.fontTiny,
            fontWeight: AppFonts.heavy,
          ),
        ),
      ],
    );
  }
}
