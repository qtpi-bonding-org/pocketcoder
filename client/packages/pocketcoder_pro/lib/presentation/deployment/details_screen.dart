import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_cubit.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_message_mapper.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/pocketcoder_credentials.dart';
import 'adapters/details_adapter.dart';

/// Details screen showing instance connection information.
class DetailsScreen extends StatelessWidget {
  const DetailsScreen({super.key, required this.instanceId});

  final String instanceId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.I<DeploymentCubit>()
        ..loadInstance(instanceId)
        ..refreshInstanceStatus(instanceId),
      child: DetailsAdapter(
        instanceId: instanceId,
        credentialStore: GetIt.I<PocketCoderCredentialStore>(),
        mapper: GetIt.I<DeploymentMessageMapper>(),
      ),
    );
  }
}
