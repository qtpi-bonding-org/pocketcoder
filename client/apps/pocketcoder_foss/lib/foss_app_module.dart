import 'package:get_it/get_it.dart';
import 'package:pocketcoder_flutter/app/app_dependency_module.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_provider_option_service.dart';
import 'package:pocketcoder_flutter/domain/edition/i_app_edition.dart';
import 'package:pocketcoder_flutter/domain/notifications/push_service.dart';
import 'package:pocketcoder_flutter/domain/system/factory_reset_hook.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_app_edition.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_billing_service.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_provider_option_service.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/ntfy_push_service.dart';
import 'package:pocketcoder_flutter/presentation/onboarding/onboarding_setup_flow.dart';

/// Injectable composition supplied by the FOSS application target.
class FossAppModule implements AppDependencyModule {
  @override
  void register(GetIt getIt) {
    getIt.registerSingleton<PushService>(NtfyPushService());
    getIt.registerSingleton<BillingService>(FossBillingService());
    getIt.registerSingleton<IAppEdition>(const FossAppEdition());
    getIt.registerSingleton<IProviderOptionService>(FossProviderOptionService());
    getIt.registerSingleton<OnboardingSetupFlow>(
      const SelfHostedOnboardingSetupFlow(),
    );
    // FOSS has no extra deployment-tracking stores beyond what AuthCubit
    // already clears directly (auth session, CA pin store).
    getIt.registerSingleton<FactoryResetHook>(const NoopFactoryResetHook());
  }
}
