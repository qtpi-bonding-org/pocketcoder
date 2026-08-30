/// Unlike capability gates (`IActiveDeploymentGate`), always registered by
/// both apps -- callers read `isPro` directly, never `getIt.isRegistered`.
abstract interface class IAppEdition {
  bool get isPro;
}
