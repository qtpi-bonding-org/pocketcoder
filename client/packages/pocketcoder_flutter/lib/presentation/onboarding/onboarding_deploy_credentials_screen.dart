import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/onboarding/deploy_credentials_cubit.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_provider_option_service.dart';
import 'adapters/deploy_credentials_adapter.dart';

class OnboardingDeployCredentialsScreen extends StatelessWidget {
  const OnboardingDeployCredentialsScreen({super.key, this.provider});

  final ProviderOption? provider;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => DeployCredentialsCubit(),
        child: DeployCredentialsAdapter(provider: provider),
      );
}
