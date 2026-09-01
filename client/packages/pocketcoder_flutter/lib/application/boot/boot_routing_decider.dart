import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_server_readiness_check.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/i_harness_auth_repository.dart';

typedef _LatchKey = (String? instanceId, String? baseUrl, String? userId);

class BootRoutingDecider {
  BootRoutingDecider({
    required IServerReadinessCheck readinessCheck,
    required AuthSessionCoordinator authCoordinator,
    required IHarnessAuthRepository harnessAuthRepository,
    required GoRouter router,
  })  : _readiness = readinessCheck,
        _auth = authCoordinator,
        _harness = harnessAuthRepository,
        _router = router;

  final IServerReadinessCheck _readiness;
  final AuthSessionCoordinator _auth;
  final IHarnessAuthRepository _harness;
  final GoRouter _router;

  StreamSubscription<ServerReadinessSnapshot>? _readinessSub;
  StreamSubscription<AuthSessionSnapshot>? _authSub;
  _LatchKey? _confirmedLatchKey;

  int _readyEpoch = 0;
  bool _wasReady = false;
  int? _restoredEpoch;
  ({int epoch, Future<void> future})? _inFlightRestore;
  int _generation = 0;

  Future<void> start() async {
    _readinessSub = _readiness.readinessChanges.listen((_) => _reconcile());
    _authSub = _auth.sessionChanges.listen((_) => _reconcile());
    await _readiness.initialize();
    await _reconcile();
  }

  void dispose() {
    _readinessSub?.cancel();
    _authSub?.cancel();
  }

  Future<void> retryAuth() async {
    _restoredEpoch = null;
    await _reconcile();
  }

  Future<void> _ensureRestoredFor(int epoch) {
    if (_restoredEpoch == epoch) return Future<void>.value();
    final inFlight = _inFlightRestore;
    if (inFlight != null && inFlight.epoch == epoch) return inFlight.future;
    late final Future<void> future;
    future = _auth.restore().then((_) {
      if (_readyEpoch == epoch) {
        _restoredEpoch = epoch;
      }
    }).whenComplete(() {
      if (identical(_inFlightRestore?.future, future)) _inFlightRestore = null;
    });
    _inFlightRestore = (epoch: epoch, future: future);
    return future;
  }

  Future<void> _reconcile() async {
    final generation = ++_generation;
    final readiness = _readiness.current;
    switch (readiness.status) {
      case ServerReadinessStatus.notProvisioned:
        _wasReady = false;
        _navigate(RouteNames.onboarding);
        return;
      case ServerReadinessStatus.provisioning:
      case ServerReadinessStatus.resumeUnrecoverable:
        _wasReady = false;
        _navigate(RouteNames.deploymentProgress);
        return;
      case ServerReadinessStatus.ready:
        break;
    }
    if (!_wasReady) {
      _readyEpoch++;
      _wasReady = true;
    }
    final epoch = _readyEpoch;

    await _ensureRestoredFor(epoch);
    if (generation != _generation) {
      return; // superseded while awaiting
    }

    final session = _auth.current;
    final latchKey = (readiness.instanceId, session.baseUrl, session.userId);
    final signOutDestination = readiness.instanceId != null
        ? RouteNames.deploymentProgress
        : RouteNames.onboardingLogin;

    switch (session.state) {
      case AuthSessionState.signedOut:
        _navigate(signOutDestination);
        return;
      case AuthSessionState.temporarilyUnavailable:
        if (latchKey != _confirmedLatchKey) {
          _navigate(signOutDestination);
          return;
        }
        break;
      case AuthSessionState.signedIn:
        break;
    }

    if (latchKey == _confirmedLatchKey &&
        _router.state.name == RouteNames.chats) {
      return;
    }

    final harnessConnected = await _harness.hasEffectiveHarnessConnection();
    if (generation != _generation) {
      return; // superseded while awaiting
    }
    _confirmedLatchKey = latchKey;
    _navigate(
        harnessConnected ? RouteNames.chats : RouteNames.onboardingHarnessAuth);
  }

  void _navigate(String routeName) {
    if (_router.state.name != routeName) _router.goNamed(routeName);
  }
}
