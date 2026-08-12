import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_cubit.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_message_mapper.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_state.dart';
import 'package:pocketcoder_pro/domain/deployment/onboarding_stage.dart';
import 'package:pocketcoder_pro/presentation/deployment/widgets/progress_view.dart';
import 'package:pocketcoder_pro/presentation/deployment/widgets/pocketcoder_progress_pane.dart';
import 'package:pocketcoder_pro/presentation/deployment/widgets/walkthrough_panel.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/github_provisioning_source_service.dart';
import 'package:flutter_aeroform/domain/models/provision_progress.dart';

class ProgressAdapter extends CubitAdapter<DeploymentCubit, DeploymentState> {
  const ProgressAdapter({
    super.key,
    required this.mapper,
    required this.sourceService,
  });

  final DeploymentMessageMapper mapper;
  final GithubProvisioningSourceService sourceService;

  static DeploymentState _selectState(DeploymentState state) => state;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<DeploymentCubit, DeploymentState> adapter,
  ) {
    final state = adapter.cubitField(_selectState);
    final cubit = context.read<DeploymentCubit>();

    return UiFlowListener<DeploymentCubit, DeploymentState>(
      mapper: mapper,
      listener: (context, value) {
        if (value.instanceId != null &&
            !cubit.isMonitoring &&
            value.deploymentStatus != OnboardingStage.ready &&
            value.deploymentStatus != OnboardingStage.failed &&
            value.hostname != null) {
          cubit.monitorDeployment(
            hostname: value.hostname ?? '',
            instanceId: value.instanceId ?? '',
          );
        }
        // Navigate to DetailsScreen on deployment completion.
        if (value.status == UiFlowStatus.success &&
            value.deploymentStatus == OnboardingStage.ready &&
            value.instance != null) {
          context.pushNamed(
            RouteNames.deploymentDetails,
            queryParameters: {'instanceId': value.instance?.id ?? ''},
          );
        }
      },
      child: ValueListenableBuilder<DeploymentState>(
        valueListenable: state,
        builder: (context, value, _) => ProgressView(
          status: value.status,
          deploymentStatus: value.deploymentStatus,
          pollingAttempts: value.pollingAttempts,
          serverStatusDocument: value.serverStatusDocument,
          progressPane: _progressPane(context, value),
          provisioningTour: WalkthroughPanel(
            stage: value.deploymentStatus,
            sourceCommit: value.serverStatusDocument?.sourceCommit,
            sourceService: sourceService,
            backend: value.backend ?? ProvisionBackendKind.nixos,
          ),
          instance: value.instance,
          error: value.error,
          onAbort: () {
            cubit.cancelDeployment();
            context.pop();
          },
          onRetry: value.instanceId == null
              ? null
              : () => cubit.monitorDeployment(
                    hostname: value.hostname ?? '',
                    instanceId: value.instanceId ?? '',
                  ),
        ),
      ),
    );
  }

  PocketCoderProgressPane _progressPane(
    BuildContext context,
    DeploymentState value,
  ) {
    final stage = value.deploymentStatus;
    final failed =
        value.status == UiFlowStatus.failure || stage == OnboardingStage.failed;
    final complete = stage == OnboardingStage.ready;
    final provisionStages = const [
      OnboardingStage.validating,
      OnboardingStage.creatingServer,
      OnboardingStage.preparingHost,
      OnboardingStage.hostReady,
      OnboardingStage.securingConnection,
    ];
    final deployStages = const [
      OnboardingStage.installingHost,
      OnboardingStage.fetchingRelease,
      OnboardingStage.loadingImages,
      OnboardingStage.startingServices,
      OnboardingStage.finishingUp,
      OnboardingStage.ready,
    ];
    final isProvisioning = stage == null || provisionStages.contains(stage);
    final isDeploying = deployStages.contains(stage);
    final detail = value.serverStatusDocument?.detail;
    final currentStep = detail?.trim().isNotEmpty == true
        ? detail!.trim()
        : (stage?.name.replaceAllMapped(
              RegExp(r'([a-z])([A-Z])'),
              (match) => '${match.group(1)} ${match.group(2)}',
            ) ??
            context.l10n.pocketCoderProgressInitializing);

    final provisionState = failed && isProvisioning
        ? PocketCoderProgressPhaseState.failed
        : isProvisioning
            ? PocketCoderProgressPhaseState.running
            : PocketCoderProgressPhaseState.complete;
    final deployState = failed && isDeploying
        ? PocketCoderProgressPhaseState.failed
        : complete
            ? PocketCoderProgressPhaseState.complete
            : isDeploying
                ? PocketCoderProgressPhaseState.running
                : PocketCoderProgressPhaseState.waiting;
    String progressText(PocketCoderProgressPhaseState state) => switch (state) {
          PocketCoderProgressPhaseState.waiting =>
            context.l10n.pocketCoderProgressWaiting,
          PocketCoderProgressPhaseState.running =>
            context.l10n.pocketCoderProgressActive,
          PocketCoderProgressPhaseState.complete =>
            context.l10n.pocketCoderProgressComplete,
          PocketCoderProgressPhaseState.failed =>
            context.l10n.pocketCoderProgressFailed,
        };

    return PocketCoderProgressPane(
      provision: PocketCoderProgressPhase(
        label: context.l10n.pocketCoderProgressProvisionServer,
        progress: isProvisioning ? _phaseProgress(stage, provisionStages) : 1,
        currentStep: isProvisioning
            ? currentStep
            : (failed
                ? context.l10n.pocketCoderProgressFailed
                : context.l10n.pocketCoderProgressComplete),
        state: provisionState,
        progressText: progressText(provisionState),
      ),
      deploy: PocketCoderProgressPhase(
        label: context.l10n.pocketCoderProgressDeployPocketCoder,
        progress: isDeploying ? _phaseProgress(stage, deployStages) : 0,
        currentStep: isDeploying
            ? currentStep
            : (complete
                ? context.l10n.pocketCoderProgressComplete
                : context.l10n.pocketCoderProgressWaiting),
        state: deployState,
        progressText: progressText(deployState),
      ),
    );
  }

  double _phaseProgress(OnboardingStage? stage, List<OnboardingStage> phases) {
    final index = stage == null ? 0 : phases.indexOf(stage);
    if (index < 0) return 0;
    return (index + 1) / phases.length;
  }
}
