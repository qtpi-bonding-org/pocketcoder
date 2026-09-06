/// `waitingForCredentials`/`signingIn` are non-terminal -- treat as "don't
/// know yet" for the matching instance, mirroring `ServerReadinessStatus.resolving`.
enum DeploymentAuthPhase {
  waitingForCredentials,
  signingIn,
  authenticated,
  failed,
}

class DeploymentAuthStatusSnapshot {
  const DeploymentAuthStatusSnapshot({
    required this.instanceId,
    required this.phase,
    this.error,
  });

  final String instanceId;
  final DeploymentAuthPhase phase;
  final Object? error;
}

/// Registered in DI only by builds that have a managed deployment flow
/// (pocketcoder_pro); absent in the OSS/self-host build, where callers must
/// guard with `getIt.isRegistered<IDeploymentAuthStatus>()`.
abstract interface class IDeploymentAuthStatus {
  DeploymentAuthStatusSnapshot? get current;

  /// Emits whenever [current] changes -- including terminal transitions
  /// (into `authenticated`/`failed`) that a caller needs to react to even
  /// though nothing else in the app necessarily changed at the same moment.
  Stream<void> get changes;
}
