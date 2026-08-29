/// App-specific cleanup a factory reset must also perform, on top of the
/// shared auth-session and CA-pin reset AuthCubit already knows how to do
/// on its own. Different app targets register their own implementation via
/// their AppDependencyModule (see FossAppModule) or equivalent startup
/// wiring (see the Pro app's main.dart) -- the same per-app override
/// pattern already used for OnboardingSetupFlow/PushService/BillingService.
abstract class FactoryResetHook {
  Future<void> resetForFactoryReset();
}

class NoopFactoryResetHook implements FactoryResetHook {
  const NoopFactoryResetHook();

  @override
  Future<void> resetForFactoryReset() async {}
}
