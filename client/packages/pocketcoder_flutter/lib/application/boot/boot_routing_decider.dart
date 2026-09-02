import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_instance_existence_resolver.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_server_readiness_check.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/i_harness_auth_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';

typedef _LatchKey = (String? instanceId, String? baseUrl, String? userId);

class BootRoutingDecider {
  BootRoutingDecider({
    required IServerReadinessCheck readinessCheck,
    required AuthSessionCoordinator authCoordinator,
    required IHarnessAuthRepository harnessAuthRepository,
    required GoRouter router,
    IInstanceExistenceResolver? instanceExistenceResolver,
  })  : _readiness = readinessCheck,
        _auth = authCoordinator,
        _harness = harnessAuthRepository,
        _router = router,
        _instanceExistence = instanceExistenceResolver;

  final IServerReadinessCheck _readiness;
  final AuthSessionCoordinator _auth;
  final IHarnessAuthRepository _harness;
  final GoRouter _router;
  final IInstanceExistenceResolver? _instanceExistence;

  StreamSubscription<ServerReadinessSnapshot>? _readinessSub;
  StreamSubscription<AuthSessionSnapshot>? _authSub;
  _LatchKey? _confirmedLatchKey;

  int _readyEpoch = 0;
  bool _wasReady = false;
  int? _restoredEpoch;
  ({int epoch, Future<void> future})? _inFlightRestore;
  Future<InstanceExistenceResult>? _inFlightExistenceCheck;
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

  Future<InstanceExistenceResult> _resolveExistenceOnce(
    IInstanceExistenceResolver resolver,
  ) {
    final inFlight = _inFlightExistenceCheck;
    if (inFlight != null) return inFlight;
    final future = (() async {
      try {
        return await resolver.checkInstanceExists();
      } on Object catch (error) {
        AppLogger.debug('BootRoutingDecider instance existence check failed', {
          'error': error.toString(),
        });
        return InstanceExistenceResult.unknown;
      }
    })();
    _inFlightExistenceCheck = future;
    future.whenComplete(() {
      if (identical(_inFlightExistenceCheck, future)) {
        _inFlightExistenceCheck = null;
      }
    });
    return future;
  }

  Future<void> _reconcile() async {
    final generation = ++_generation;
    final readiness = _readiness.current;
    AppLogger.debug('BootRoutingDecider reconcile', {
      'generation': generation,
      'readinessStatus': readiness.status.name,
      'instanceId': readiness.instanceId,
    });
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
    AppLogger.debug('BootRoutingDecider session', {
      'generation': generation,
      'sessionState': session.state.name,
      'latchKey': latchKey.toString(),
      'confirmedLatchKey': _confirmedLatchKey?.toString(),
    });

    switch (session.state) {
      case AuthSessionState.signedOut:
        _navigate(signOutDestination);
        return;
      case AuthSessionState.temporarilyUnavailable:
        if (latchKey != _confirmedLatchKey) {
          final resolver = _instanceExistence;
          if (resolver != null) {
            final result = await _resolveExistenceOnce(resolver);
            if (generation != _generation) {
              return; // superseded while awaiting
            }
            AppLogger.debug('BootRoutingDecider instance existence', {
              'generation': generation,
              'result': result.name,
            });
            switch (result) {
              case InstanceExistenceResult.unknown:
                _navigate(RouteNames.instanceUnverifiable);
                return;
              case InstanceExistenceResult.gone:
                return;
              case InstanceExistenceResult.exists:
                break;
            }
          }
          _navigate(signOutDestination);
          return;
        }
        break;
      case AuthSessionState.signedIn:
        break;
    }

    if (latchKey == _confirmedLatchKey &&
        _currentRouteName() == RouteNames.chats) {
      return;
    }

    final harnessConnected = await _harness.hasEffectiveHarnessConnection();
    if (generation != _generation) {
      return; // superseded while awaiting
    }
    AppLogger.debug('BootRoutingDecider harness check', {
      'generation': generation,
      'harnessConnected': harnessConnected,
    });
    _confirmedLatchKey = latchKey;
    _navigate(
        harnessConnected ? RouteNames.chats : RouteNames.onboardingHarnessAuth);
  }

  void _navigate(String routeName) {
    final current = _currentRouteName();
    final navigating = current != routeName;
    AppLogger.debug('BootRoutingDecider navigate', {
      'requested': routeName,
      'current': current,
      'navigating': navigating,
    });
    if (navigating) _router.goNamed(routeName);
  }

  /// GoRouter.state can throw (empty RouteMatchList) before first resolution.
  String? _currentRouteName() {
    try {
      return _router.state.name;
    } on StateError {
      return null;
    }
  }
}
