import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/onboarding/deploy_credentials_cubit.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/deploy_credentials_view.dart';

class DeployCredentialsAdapter
    extends CubitAdapter<DeployCredentialsCubit, DeployCredentialsState> {
  const DeployCredentialsAdapter({super.key});

  @override
  Widget buildAdapter(
      BuildContext context,
      CubitAdapterState<DeployCredentialsCubit, DeployCredentialsState>
          adapter) {
    final state = adapter.cubitField((value) => value);
    final cubit = context.read<DeployCredentialsCubit>();
    return ValueListenableBuilder<DeployCredentialsState>(
      valueListenable: state,
      builder: (context, value, _) => DeployCredentialsView(
        email: value.email,
        password: value.password,
        onEmailChanged: cubit.setEmail,
        onPasswordChanged: cubit.setPassword,
        onContinue: () {
          final current = cubit.state;
          context.pushNamed(
            RouteNames.deploy,
            extra: DeployCredentials(
              email: current.email.trim(),
              password: current.password,
            ),
          );
        },
      ),
    );
  }
}
