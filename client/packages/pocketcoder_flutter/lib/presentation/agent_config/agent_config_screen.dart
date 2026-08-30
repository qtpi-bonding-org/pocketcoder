import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/agent_config/agent_config_cubit.dart';
import 'package:pocketcoder_flutter/application/provider/provider_cubit.dart';
import 'adapters/agent_config_adapter.dart';

class AgentConfigScreen extends StatelessWidget {
  const AgentConfigScreen({super.key});
  @override
  Widget build(BuildContext context) => MultiBlocProvider(
        providers: [
          BlocProvider<AgentConfigCubit>(
            create: (_) => getIt<AgentConfigCubit>()..watchAll(),
          ),
          BlocProvider<ProviderCubit>(
            create: (_) => getIt<ProviderCubit>()..watchAll(),
          ),
        ],
        child: const AgentConfigAdapter(),
      );
}
