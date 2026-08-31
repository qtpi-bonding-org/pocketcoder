import 'package:pocketcoder_flutter/domain/security/i_ssh_key_generator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/app/app_dependency_module.dart';
import 'package:pocketcoder_flutter/application/foss/foss_server_setup_cubit.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_provider_option_service.dart';
import 'package:pocketcoder_flutter/domain/edition/i_app_edition.dart';
import 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_command_runner.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_credentials_provider.dart';
import 'package:pocketcoder_flutter/domain/release/i_server_release_status_service.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_connection_details_provider.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_control_service.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_control_setup_gate.dart';
import 'package:pocketcoder_flutter/domain/system/factory_reset_hook.dart';
import 'package:pocketcoder_flutter/domain/system/pro_data_deletion_hook.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_app_edition.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_billing_service.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_provider_option_service.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_root_ssh_connection_tester.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_root_ssh_credentials_provider.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_root_ssh_credentials_store.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_server_connection_details_provider.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_server_control_setup_gate.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/ntfy_push_service.dart';
import 'package:pocketcoder_flutter/infrastructure/os_control/ssh_root_command_runner.dart';
import 'package:pocketcoder_flutter/infrastructure/server_control/ssh_server_control_service.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_setup_flow.dart';

/// Injectable composition supplied by the FOSS application target.
class FossAppModule implements AppDependencyModule {
  @override
  void register(GetIt getIt) {
    getIt.registerSingleton<PushService>(NtfyPushService());
    getIt.registerSingleton<BillingService>(FossBillingService());
    getIt.registerSingleton<IAppEdition>(const FossAppEdition());
    getIt
        .registerSingleton<IProviderOptionService>(FossProviderOptionService());
    getIt.registerSingleton<OnboardingSetupFlow>(
      const SelfHostedOnboardingSetupFlow(),
    );
    // FOSS has no extra deployment-tracking stores beyond what AuthCubit
    // already clears directly (auth session, CA pin store).
    getIt.registerSingleton<FactoryResetHook>(const NoopFactoryResetHook());
    // FOSS has no PocketCoder-Pro-hosted data (no push-relay, no
    // RevenueCat) -- nothing for this hook to purge.
    getIt.registerSingleton<ProDataDeletionHook>(
      const NoopProDataDeletionHook(),
    );
    getIt.registerLazySingleton<FossRootSshCredentialsStore>(
      () => FossRootSshCredentialsStore(getIt<FlutterSecureStorage>()),
    );
    // ISshKeyGenerator is registered by pocketcoder_flutter's own
    // injectable-generated config (see SshKeyGenerator's @LazySingleton),
    // same as ILocalAuthGate -- not manually registered here.
    getIt.registerFactory<FossServerSetupCubit>(
      () => FossServerSetupCubit(
        getIt<ISshKeyGenerator>(),
        FossRootSshConnectionTester(),
        getIt<FossRootSshCredentialsStore>(),
        getIt<PocketBase>(),
      ),
    );
    getIt.registerLazySingleton<IServerControlSetupGate>(
      () => FossServerControlSetupGate(getIt<FossRootSshCredentialsStore>()),
    );
    getIt.registerLazySingleton<IRootSshCredentialsProvider>(
      () =>
          FossRootSshCredentialsProvider(getIt<FossRootSshCredentialsStore>()),
    );
    getIt.registerLazySingleton<IRootSshCommandRunner>(
      () => SshRootCommandRunner(
        credentialsProvider: getIt<IRootSshCredentialsProvider>(),
      ),
    );
    getIt.registerLazySingleton<IServerConnectionDetailsProvider>(
      () => const FossServerConnectionDetailsProvider(),
    );
    getIt.registerLazySingleton<IServerControlService>(
      () => SshServerControlService(
        rootSshCommandRunner: getIt<IRootSshCommandRunner>(),
        pocketBase: getIt<PocketBase>(),
        releaseStatusService: getIt<IServerReleaseStatusService>(),
        credentialsProvider: getIt<IRootSshCredentialsProvider>(),
      ),
    );
  }
}
