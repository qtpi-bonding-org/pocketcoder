import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/application/provider/provider_cubit.dart';
import 'package:pocketcoder_flutter/application/provider/provider_state.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/widgets/harness_choice_view.dart';
import 'package:pocketcoder_flutter/support/onboarding_logger.dart';

class HarnessChoiceAdapter extends CubitAdapter<ProviderCubit, ProviderState> {
  const HarnessChoiceAdapter({super.key});

  static List<Harnesse> selectHarnesses(ProviderState state) => state.harnesses;

  @override
  Widget buildAdapter(
    BuildContext context,
    CubitAdapterState<ProviderCubit, ProviderState> adapter,
  ) {
    final harnesses = adapter.cubitField(selectHarnesses);
    final status = adapter.cubitStatus();
    return ValueListenableBuilder<UiFlowStatus>(
      valueListenable: status,
      builder: (context, status, _) => ValueListenableBuilder<List<Harnesse>>(
        valueListenable: harnesses,
        builder: (context, harnesses, _) => HarnessChoiceView(
          status: status,
          harnesses: harnesses,
          error: context.read<ProviderCubit>().state.error,
          onSelected: (harness) => _select(context, harness),
        ),
      ),
    );
  }

  void _select(BuildContext context, Harnesse harness) {
    final cli = harness.cliId.toLowerCase();
    final route = cli == 'codex'
        ? RouteNames.onboardingCodexAuth
        : RouteNames.onboardingClaudeAuth;
    OnboardingLogger.event('harness selected', {
      'harness': harness.id,
      'cli': cli,
    });
    context.pushNamed(route, extra: harness.id);
  }
}
