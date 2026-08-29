import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/adapters/self_host_login_adapter.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_prefill.dart';

class SelfHostLoginScreen extends StatelessWidget {
  const SelfHostLoginScreen({super.key, this.prefill});

  final OnboardingPrefill? prefill;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.I<AuthCubit>()..restoreSavedUrl(),
      child: SelfHostLoginAdapter(prefill: prefill),
    );
  }
}
