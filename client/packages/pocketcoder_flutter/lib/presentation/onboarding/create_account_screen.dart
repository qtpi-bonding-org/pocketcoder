import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/onboarding/create_account_cubit.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_provider_option_service.dart';
import 'adapters/create_account_adapter.dart';

class CreateAccountScreen extends StatelessWidget {
  const CreateAccountScreen({super.key, this.provider});

  final ProviderOption? provider;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => CreateAccountCubit(),
        child: CreateAccountAdapter(provider: provider),
      );
}
