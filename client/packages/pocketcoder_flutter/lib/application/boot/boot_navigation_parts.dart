import 'package:nav_snapshot/nav_snapshot.dart';
import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deployment_auth_status.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_instance_existence_resolver.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_server_readiness_check.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/i_harness_auth_repository.dart';

/// Identifies the deployment, server and user a confirmed session belongs to.
typedef LatchKey = (String? instanceId, String? baseUrl, String? userId);

/// The inputs the boot policy reads. Constructs parts; decides nothing.
class BootNavigationParts {
  BootNavigationParts({
    required IServerReadinessCheck readinessCheck,
    required AuthSessionCoordinator authCoordinator,
    required IHarnessAuthRepository harnessAuthRepository,
    IInstanceExistenceResolver? instanceExistenceResolver,
    IDeploymentAuthStatus? deploymentAuthStatus,
    Duration unknownExistenceRetryDelay = const Duration(seconds: 2),
    int maxUnknownExistenceRetries = 3,
  }) {
    readiness = SnapshotPart<ServerReadinessSnapshot>.observed(
      name: 'readiness',
      read: () => readinessCheck.current,
      changes: readinessCheck.readinessChanges.map((_) {}),
    );
    session = SnapshotPart<AuthSessionSnapshot>.observed(
      name: 'session',
      read: () => authCoordinator.current,
      changes: authCoordinator.sessionChanges.map((_) {}),
    );
    deploymentAuth = deploymentAuthStatus == null
        ? null
        : SnapshotPart<DeploymentAuthStatusSnapshot?>.observed(
            name: 'deploymentAuth',
            read: () => deploymentAuthStatus.current,
            changes: deploymentAuthStatus.changes,
          );
    // A void part: nothing reads its value, the policy only gates on its
    // completion. restore() publishes a new session snapshot as a side
    // effect, which the `session` part above observes.
    authRestore = SnapshotPart<void>(
      name: 'authRestore',
      load: () async {
        await authCoordinator.restore();
      },
    );
    existence = instanceExistenceResolver == null
        ? null
        : SnapshotPart<InstanceExistenceResult>(
            name: 'existence',
            load: instanceExistenceResolver.checkInstanceExists,
            retry: RetryConfig<InstanceExistenceResult>(
              maxAttempts: maxUnknownExistenceRetries,
              delay: unknownExistenceRetryDelay,
              retryOnValue: (value) => value == InstanceExistenceResult.unknown,
            ),
            // A sign-in drops the answer, matching
            // boot_routing_decider.dart:214-217 without mutating during an
            // evaluation. signInGeneration is monotone on purpose: a boolean
            // would flip back to false before anything read it, and the
            // stale answer would survive (D4).
            cacheKey: () => (
              readyEpoch,
              readiness.peek().valueOrNull?.instanceId,
              signInGeneration,
            ),
          );
    // Deliberately uncached (D5). The original probes on every reconcile that
    // reaches it; the shell invalidates this part per input event instead.
    harness = SnapshotPart<bool>(
      name: 'harness',
      load: harnessAuthRepository.hasEffectiveHarnessConnection,
    );

    // The ready edge, registered here so it runs before the binding
    // subscribes (D8). A separate subscription in the shell would fire
    // second and let one evaluation see a stale authRestore.
    readiness.addListener(_onReadinessChanged);
    _wasReady =
        readiness.peek().valueOrNull?.status == ServerReadinessStatus.ready;
    // The sign-in generation backing the existence cacheKey (D4).
    session.addListener(_onSessionChanged);
    _wasSignedIn =
        session.peek().valueOrNull?.state == AuthSessionState.signedIn;
  }

  /// Builds a bundle from already-seeded parts. For tests only.
  BootNavigationParts.seeded({
    required this.readiness,
    required this.session,
    required this.authRestore,
    required this.harness,
    this.deploymentAuth,
    this.existence,
  });

  /// Bumped on the not-ready to ready edge.
  int readyEpoch = 0;
  /// Bumped on each signed-out to signed-in edge. Monotone by design (D4).
  int signInGeneration = 0;
  bool _wasReady = false;
  bool _wasSignedIn = false;

  late final SnapshotPart<ServerReadinessSnapshot> readiness;
  late final SnapshotPart<AuthSessionSnapshot> session;
  late final SnapshotPart<DeploymentAuthStatusSnapshot?>? deploymentAuth;
  late final SnapshotPart<void> authRestore;
  late final SnapshotPart<InstanceExistenceResult>? existence;
  late final SnapshotPart<bool> harness;

  void _onReadinessChanged() {
    final isReady =
        readiness.peek().valueOrNull?.status == ServerReadinessStatus.ready;
    if (isReady && !_wasReady) {
      readyEpoch++;
      authRestore.invalidate();
    }
    _wasReady = isReady;
    // One probe per input event, matching the original (D5).
    harness.invalidate();
  }

  void _onSessionChanged() {
    final isSignedIn =
        session.peek().valueOrNull?.state == AuthSessionState.signedIn;
    if (isSignedIn && !_wasSignedIn) signInGeneration++;
    _wasSignedIn = isSignedIn;
    harness.invalidate();
  }

  /// The identity a confirmed session belongs to.
  LatchKey latchKey() {
    final currentSession = session.peek().valueOrNull;
    return (
      readiness.peek().valueOrNull?.instanceId,
      currentSession?.baseUrl,
      currentSession?.userId,
    );
  }

  /// Every part, for lifecycle. Absent optional parts are omitted.
  List<SnapshotPart<Object?>> get all => <SnapshotPart<Object?>>[
        readiness,
        session,
        if (deploymentAuth case final part?) part,
        authRestore,
        if (existence case final part?) part,
        harness,
      ];

  void dispose() {
    for (final part in all) {
      part.dispose();
    }
  }
}
