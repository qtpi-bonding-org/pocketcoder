import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/provider/provider_cubit.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/adapters/choose_agent_adapter.dart';

class ChooseAgentScreen extends StatelessWidget {
  const ChooseAgentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ProviderCubit>()..watchAll(),
      child: const ChooseAgentAdapter(),
    );
  }
}
