/// Lets generic boot/onboarding flow ask "is there already a fully
/// provisioned, ready-to-log-into deployment for this device?" without
/// depending on `pocketcoder_pro`'s deployment engine types.
///
/// Registered in DI only by builds that have a managed deployment flow
/// (pocketcoder_pro); absent in the OSS/self-host build, where callers
/// must guard with `getIt.isRegistered<IActiveDeploymentGate>()`.
abstract class IActiveDeploymentGate {
  bool get hasReadyDeployment;

  /// True for a deployment that's either ready OR still actively
  /// provisioning/deploying. BootScreen's own connection-check race can
  /// clobber an in-progress deployment's route just as easily as a ready
  /// one's -- [hasReadyDeployment] alone only guards the already-ready
  /// half of that incident.
  bool get hasActiveDeployment;
}
