import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_cubit.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';
import 'package:pocketcoder_flutter/infrastructure/harness_auth/harness_auth_repository.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/adapters/agent_login_adapter.dart';

class AgentLoginScreen extends StatelessWidget {
  const AgentLoginScreen({
    super.key,
    required this.harnessId,
    required this.provider,
  });

  final String harnessId;
  final String provider;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HarnessAuthCubit(
        providerRepository: getIt<IProviderRepository>(),
        authRepository: HarnessAuthRepository(
          getIt<PocketCoderApiClient>(),
          getIt<IAuthRepository>(),
        ),
      )..watchData(),
      child: AgentLoginAdapter(
        harnessId: harnessId,
        provider: provider,
      ),
    );
  }
}
