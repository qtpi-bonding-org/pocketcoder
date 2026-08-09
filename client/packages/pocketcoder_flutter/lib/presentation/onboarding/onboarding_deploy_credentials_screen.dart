import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/onboarding/deploy_credentials_cubit.dart';
import 'adapters/deploy_credentials_adapter.dart';

class OnboardingDeployCredentialsScreen extends StatelessWidget {
  const OnboardingDeployCredentialsScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => DeployCredentialsCubit(),
        child: const DeployCredentialsAdapter(),
      );
}
