import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_cubit.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_message_mapper.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/github_provisioning_source_service.dart';
import 'adapters/progress_adapter.dart';

/// Progress screen showing deployment status.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DeploymentCubit>(
      create: (_) {
        final cubit = GetIt.I<DeploymentCubit>();
        final state = cubit.state;
        if (state.instanceId != null &&
            state.hostname != null &&
            !cubit.isMonitoring) {
          final hostname = state.hostname;
          final instanceId = state.instanceId;
          if (hostname == null || instanceId == null) return cubit;
          cubit.monitorDeployment(
            hostname: hostname,
            instanceId: instanceId,
          );
        }
        return cubit;
      },
      child: ProgressAdapter(
        mapper: GetIt.I<DeploymentMessageMapper>(),
        sourceService: GetIt.I<GithubProvisioningSourceService>(),
      ),
    );
  }
}
