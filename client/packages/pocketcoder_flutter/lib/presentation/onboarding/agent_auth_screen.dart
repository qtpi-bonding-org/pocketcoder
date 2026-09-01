import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/provider/provider_cubit.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_cubit.dart';
import 'package:pocketcoder_flutter/presentation/core/in_app_browser_launcher.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/adapters/agent_auth_adapter.dart';

class AgentAuthScreen extends StatelessWidget {
  const AgentAuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<ProviderCubit>()..watchAll()),
        BlocProvider(create: (_) => getIt<HarnessAuthCubit>()..watchData()),
      ],
      // Terminal onboarding step: SKIP is the only sanctioned exit, so the
      // platform back gesture/button must not pop this screen either.
      child: PopScope(
        canPop: false,
        child: AgentAuthAdapter(launcher: getIt<InAppBrowserLauncher>()),
      ),
    );
  }
}
