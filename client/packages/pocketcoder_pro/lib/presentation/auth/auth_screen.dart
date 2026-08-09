import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_pro/application/auth/auth_cubit.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/presentation/deployment/deploy_credentials.dart';
import 'adapters/auth_adapter.dart';

/// Authentication screen for Linode OAuth login.
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key, this.credentials});

  final DeployCredentials? credentials;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AuthCubit>(),
      child: AuthAdapter(credentials: credentials),
    );
  }
}
