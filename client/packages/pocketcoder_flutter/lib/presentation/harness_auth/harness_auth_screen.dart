import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_cubit.dart';
import 'package:pocketcoder_flutter/presentation/harness_auth/adapters/harness_auth_adapter.dart';

class HarnessAuthScreen extends StatelessWidget {
  const HarnessAuthScreen({super.key, this.onboarding = false});

  final bool onboarding;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<HarnessAuthCubit>()..watchData(),
      child: HarnessAuthAdapter(onboarding: onboarding),
    );
  }
}
