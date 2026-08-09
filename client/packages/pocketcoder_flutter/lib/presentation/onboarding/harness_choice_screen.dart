import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/provider/provider_cubit.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/adapters/harness_choice_adapter.dart';

class HarnessChoiceScreen extends StatelessWidget {
  const HarnessChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ProviderCubit>()..watchAll(),
      child: const HarnessChoiceAdapter(),
    );
  }
}
