import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:pocketcoder_foss/foss_app_module.dart';
import 'package:pocketcoder_flutter/application/foss/foss_server_setup_cubit.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_provider_option_service.dart';
import 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_command_runner.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_credentials_provider.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_connection_details_provider.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_control_service.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_control_setup_gate.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_setup_flow.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_root_ssh_credentials_store.dart';

void main() {
  test('FOSS app module registers every shared app-level binding', () {
    final getIt = GetIt.asNewInstance();
    addTearDown(getIt.reset);

    FossAppModule().register(getIt);

    expect(getIt<PushService>(), isA<PushService>());
    expect(getIt<BillingService>(), isA<BillingService>());
    expect(getIt<IProviderOptionService>(), isA<IProviderOptionService>());
    expect(getIt<OnboardingSetupFlow>(), isA<OnboardingSetupFlow>());
    expect(getIt.isRegistered<FossRootSshCredentialsStore>(), isTrue);
    expect(getIt.isRegistered<FossServerSetupCubit>(), isTrue);
    expect(getIt.isRegistered<IServerControlSetupGate>(), isTrue);
    expect(getIt.isRegistered<IRootSshCredentialsProvider>(), isTrue);
    expect(getIt.isRegistered<IRootSshCommandRunner>(), isTrue);
    expect(getIt.isRegistered<IServerConnectionDetailsProvider>(), isTrue);
    expect(getIt.isRegistered<IServerControlService>(), isTrue);
  });
}
