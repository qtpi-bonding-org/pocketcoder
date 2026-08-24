/// Lets generic boot/onboarding flow ask "is there already a fully
/// provisioned, ready-to-log-into deployment for this device?" without
/// depending on `pocketcoder_pro`'s deployment engine types.
///
/// Registered in DI only by builds that have a managed deployment flow
/// (pocketcoder_pro); absent in the OSS/self-host build, where callers
/// must guard with `getIt.isRegistered<IActiveDeploymentGate>()`.
abstract class IActiveDeploymentGate {
  bool get hasReadyDeployment;
}
