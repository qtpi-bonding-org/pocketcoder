import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/system/poco_cubit.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/onboarding_view.dart';

class OnboardingAdapter extends CubitAdapter<PocoCubit, PocoState> {
  const OnboardingAdapter({super.key});

  @override
  Widget buildAdapter(BuildContext context, CubitAdapterState<PocoCubit, PocoState> adapter) {
    final state = adapter.cubitField((value) => value);
    return ValueListenableBuilder<PocoState>(
      valueListenable: state,
      builder: (context, value, _) => OnboardingView(
        pocoState: value,
        onLogin: () => context.pushNamed(RouteNames.onboardingLogin),
        onDeploy: () => context.pushNamed(RouteNames.onboardingDeploy),
      ),
    );
  }
}
