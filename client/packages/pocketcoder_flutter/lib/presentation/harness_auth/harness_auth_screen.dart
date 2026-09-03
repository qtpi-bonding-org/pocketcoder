import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_cubit.dart';
import 'package:pocketcoder_flutter/application/provider/provider_cubit.dart';
import 'package:pocketcoder_flutter/presentation/harness_auth/adapters/harness_auth_adapter.dart';
import 'package:pocketcoder_flutter/presentation/core/in_app_browser_launcher.dart';

class HarnessAuthScreen extends StatelessWidget {
  const HarnessAuthScreen({super.key, this.onboarding = false});

  final bool onboarding;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<HarnessAuthCubit>()..watchData()),
        BlocProvider(create: (_) => getIt<ProviderCubit>()..watchAll()),
      ],
      child: HarnessAuthAdapter(
        onboarding: onboarding,
        launcher: getIt<InAppBrowserLauncher>(),
      ),
    );
  }
}
