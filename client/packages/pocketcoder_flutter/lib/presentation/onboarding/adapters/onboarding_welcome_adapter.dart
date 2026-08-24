import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_setup_flow.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/onboarding_welcome_view.dart';

class OnboardingWelcomeAdapter extends CubitAdapter<PocoCubit, PocoState> {
  const OnboardingWelcomeAdapter({super.key});

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<PocoCubit, PocoState> adapter,
  ) {
    final setupFlow = getIt<OnboardingSetupFlow>();
    return OnboardingWelcomeView(
      showGuidedSetup: setupFlow.offersGuidedSetup,
      onGuidedSetup: () => setupFlow.startGuidedSetup(context),
      onSelfHost: () => setupFlow.showSelfHostInformation(context),
    );
  }
}
