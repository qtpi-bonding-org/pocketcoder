import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_pro/application/config/config_cubit.dart';
import 'package:pocketcoder_pro/application/deployment/deployment_cubit.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:flutter_aeroform/domain/security/i_ssh_key_generator.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
import 'adapters/config_adapter.dart';

/// Configuration screen for deployment settings.
class ConfigScreen extends StatelessWidget {
  const ConfigScreen({super.key, this.credentials});

  final DeployCredentials? credentials;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<ConfigCubit>()..loadPlansAndRegions(),
        ),
        BlocProvider.value(
          value: getIt<DeploymentCubit>()..resetDeployment(),
        ),
      ],
      child: ConfigAdapter(
        credentials: credentials,
        sshKeyGenerator: getIt<ISshKeyGenerator>(),
      ),
    );
  }
}
