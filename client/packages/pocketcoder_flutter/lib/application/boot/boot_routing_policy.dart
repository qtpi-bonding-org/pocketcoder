import 'package:nav_snapshot/nav_snapshot.dart';
import 'package:pocketcoder_flutter/application/boot/boot_navigation_parts.dart';
import 'package:pocketcoder_flutter/application/boot/boot_route.dart';
import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deployment_auth_status.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_instance_existence_resolver.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_server_readiness_check.dart';

/// The boot decision matrix, as a pure synchronous function of its parts.
class BootRoutingPolicy extends NavigationPolicy<BootRoute> {
  BootRoutingPolicy({
    required this.inputs,
    required BootRoute? Function() currentRoute,
    required bool Function() bootFloorElapsed,
    this.confirmedLatchKey,
    this.lastDeployProgressRoute,
    this.hasLeftBootScreen = false,
  })  : _currentRoute = currentRoute,
        _bootFloorElapsed = bootFloorElapsed;

  final BootNavigationParts inputs;
  final BootRoute? Function() _currentRoute;
  final bool Function() _bootFloorElapsed;
  LatchKey? confirmedLatchKey;
  BootRoute? lastDeployProgressRoute;
  bool hasLeftBootScreen;
  LatchKey? _pendingLatchKey;

  @override
  List<SnapshotPart<Object?>> get parts => inputs.all;

  @override
  RouteDecision<BootRoute> decide() {
    final readiness = inputs.readiness.read().valueOrNull;
    if (readiness == null) return const RouteWait<BootRoute>();
    switch (readiness.status) {
      case ServerReadinessStatus.resolving:
        return const RouteWait<BootRoute>();
      case ServerReadinessStatus.notProvisioned:
        if (!hasLeftBootScreen && !_bootFloorElapsed()) {
          return const RouteWait<BootRoute>();
        }
        return _deployPhase(BootRoute.onboarding);
      case ServerReadinessStatus.provisioning:
      case ServerReadinessStatus.resumeUnrecoverable:
        return _deployPhase(BootRoute.deploymentProgress);
      case ServerReadinessStatus.ready:
        break;
    }

    if (inputs.authRestore.read() is! PartReady<void>) {
      return const RouteWait<BootRoute>();
    }
    final deploymentAuth = inputs.deploymentAuth?.read().valueOrNull;
    if (deploymentAuth != null &&
        deploymentAuth.instanceId == readiness.instanceId &&
        (deploymentAuth.phase == DeploymentAuthPhase.waitingForCredentials ||
            deploymentAuth.phase == DeploymentAuthPhase.signingIn)) {
      return const RouteWait<BootRoute>();
    }
    final session = inputs.session.read().valueOrNull;
    if (session == null) return const RouteWait<BootRoute>();

    final LatchKey latchKey =
        (readiness.instanceId, session.baseUrl, session.userId);
    _pendingLatchKey = latchKey;
    final authOk = switch (session.state) {
      AuthSessionState.signedIn => true,
      AuthSessionState.temporarilyUnavailable => latchKey == confirmedLatchKey,
      AuthSessionState.signedOut => false,
    };
    if (!authOk) return _signedOutDecision();

    if (latchKey == confirmedLatchKey && _currentRoute() == BootRoute.chats) {
      return const RouteStay<BootRoute>();
    }
    final harness = inputs.harness.read();
    if (harness is! PartReady<bool>) return const RouteWait<BootRoute>();
    return RouteGo<BootRoute>(
      harness.value ? BootRoute.chats : BootRoute.harnessAuth,
    );
  }

  RouteDecision<BootRoute> _signedOutDecision() {
    final existence = inputs.existence;
    if (existence == null) return const RouteGo<BootRoute>(BootRoute.login);
    final state = existence.read();
    if (state is PartLoading<InstanceExistenceResult>) {
      return const RouteWait<BootRoute>();
    }
    if (state is PartFailed<InstanceExistenceResult> || state.exhausted) {
      return const RouteGo<BootRoute>(BootRoute.instanceUnverifiable);
    }
    return switch (state.valueOrNull) {
      InstanceExistenceResult.exists =>
        const RouteGo<BootRoute>(BootRoute.login),
      InstanceExistenceResult.gone =>
        const RouteGo<BootRoute>(BootRoute.instanceGone),
      InstanceExistenceResult.unknown => const RouteWait<BootRoute>(),
      null => const RouteWait<BootRoute>(),
    };
  }

  RouteDecision<BootRoute> _deployPhase(BootRoute route) {
    final last = lastDeployProgressRoute;
    if (last != null && _currentRoute() != last) {
      return const RouteStay<BootRoute>();
    }
    return RouteGo<BootRoute>(route);
  }

  @override
  void onDecisionApplied(BootRoute route, {required bool navigated}) {
    if (navigated) hasLeftBootScreen = true;
    if (route == BootRoute.chats || route == BootRoute.harnessAuth) {
      confirmedLatchKey = _pendingLatchKey;
    }
    if (route == BootRoute.deploymentProgress) {
      lastDeployProgressRoute = route;
    } else if (route == BootRoute.onboarding) {
      lastDeployProgressRoute = null;
    }
  }
}
