import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_cubit.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_message_mapper.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_state.dart';
import 'package:pocketcoder_pro/domain/deployment/onboarding_stage.dart';
import 'package:pocketcoder_pro/presentation/deployment/widgets/progress_view.dart';

class ProgressAdapter extends CubitAdapter<DeploymentCubit, DeploymentState> {
  const ProgressAdapter({super.key, required this.mapper});

  final DeploymentMessageMapper mapper;

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
}
