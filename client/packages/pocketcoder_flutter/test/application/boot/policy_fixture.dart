import 'package:nav_snapshot/nav_snapshot.dart';
import 'package:pocketcoder_flutter/application/boot/boot_navigation_parts.dart';
import 'package:pocketcoder_flutter/application/boot/boot_route.dart';
import 'package:pocketcoder_flutter/application/boot/boot_routing_policy.dart';
import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deployment_auth_status.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_instance_existence_resolver.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_server_readiness_check.dart';

BootRoutingPolicy fixture({
  ServerReadinessStatus status = ServerReadinessStatus.ready,
  String? instanceId = 'i1',
  AuthSessionState sessionState = AuthSessionState.signedIn,
  bool restoreSettled = true,
  DeploymentAuthStatusSnapshot? deploymentAuth,
  InstanceExistenceResult existence = InstanceExistenceResult.exists,
  bool existenceLoading = false,
  bool existenceFailed = false,
  bool existenceExhausted = false,
  bool hasExistenceResolver = true,
  bool harnessConnected = false,
  bool harnessLoading = false,
  BootRoute? currentRoute,
  bool bootFloorElapsed = true,
  LatchKey? confirmedLatchKey,
  BootRoute? lastDeployProgressRoute,
  bool hasLeftBootScreen = false,
}) {
  final readiness = SnapshotPart<ServerReadinessSnapshot>.ready('readiness',
      ServerReadinessSnapshot(status: status, instanceId: instanceId));
  final session = SnapshotPart<AuthSessionSnapshot>.ready(
      'session',
      AuthSessionSnapshot(
          state: sessionState,
          baseUrl: 'https://server',
          userId: sessionState == AuthSessionState.signedOut ? null : 'user'));
  final restore = restoreSettled
      ? SnapshotPart<void>.ready('authRestore', null)
      : SnapshotPart<void>.loading('authRestore');
  final harness = harnessLoading
      ? SnapshotPart<bool>.loading('harness')
      : SnapshotPart<bool>.ready('harness', harnessConnected);
  SnapshotPart<InstanceExistenceResult>? exists;
  if (hasExistenceResolver) {
    if (existenceLoading) {
      exists = SnapshotPart<InstanceExistenceResult>.loading('existence');
    } else if (existenceFailed) {
      exists = SnapshotPart<InstanceExistenceResult>.failed('existence',
          error: StateError('fixture'));
    } else if (existenceExhausted) {
      exists = _ExhaustedPart(existence, 'existence');
    } else {
      exists =
          SnapshotPart<InstanceExistenceResult>.ready('existence', existence);
    }
  }
  final parts = BootNavigationParts.seeded(
    readiness: readiness,
    session: session,
    authRestore: restore,
    harness: harness,
    deploymentAuth: deploymentAuth == null
        ? null
        : SnapshotPart<DeploymentAuthStatusSnapshot?>.ready(
            'deploymentAuth', deploymentAuth),
    existence: exists,
  );
  return BootRoutingPolicy(
    inputs: parts,
    currentRoute: () => currentRoute,
    bootFloorElapsed: () => bootFloorElapsed,
    confirmedLatchKey: confirmedLatchKey,
    lastDeployProgressRoute: lastDeployProgressRoute,
    hasLeftBootScreen: hasLeftBootScreen,
  );
}

class _ExhaustedPart extends SnapshotPart<InstanceExistenceResult> {
  _ExhaustedPart(InstanceExistenceResult value, String name)
      : super.ready(name, value);
  @override
  PartState<InstanceExistenceResult> read() =>
      const PartReady<InstanceExistenceResult>(InstanceExistenceResult.unknown,
          exhausted: true);
}
