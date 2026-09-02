import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_instance_existence_resolver.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_server_readiness_check.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/i_harness_auth_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';

typedef _LatchKey = (String? instanceId, String? baseUrl, String? userId);
typedef _ExistenceKey = (int epoch, String? instanceId);

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

  /// Must equal BootScreen's own scripted timeline length (2.5s + 6.5s),
  /// since nothing here observes BootScreen's actual animation state.
  static const Duration kMinFreshInstallBootDuration =
      Duration(milliseconds: 9000);

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
  ({_ExistenceKey key, InstanceExistenceResult result})? _existenceAnswer;
  ({
    _ExistenceKey key,
    Future<InstanceExistenceResult> future
  })? _inFlightExistence;
  int _generation = 0;
  final DateTime _bootStartedAt = DateTime.now();
  bool _hasLeftBootScreen = false;

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
    _existenceAnswer = null;
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

  Future<InstanceExistenceResult> _existenceFor(
    _ExistenceKey key,
    IInstanceExistenceResolver resolver,
  ) {
    final answered = _existenceAnswer;
    if (answered != null && answered.key == key) {
      return Future<InstanceExistenceResult>.value(answered.result);
    }
    final inFlight = _inFlightExistence;
    if (inFlight != null && inFlight.key == key) {
      return inFlight.future;
    }
    late final Future<InstanceExistenceResult> future;
    future = Future(() async {
      try {
        return await resolver.checkInstanceExists();
      } on Object catch (error) {
        AppLogger.debug('BootRoutingDecider instance existence check failed', {
          'error': error.toString(),
        });
        return InstanceExistenceResult.unknown;
      }
    }).then((result) {
      if (identical(_inFlightExistence?.future, future)) {
        _existenceAnswer = (key: key, result: result);
      }
      return result;
    }).whenComplete(() {
      if (identical(_inFlightExistence?.future, future)) {
        _inFlightExistence = null;
      }
    });
    _inFlightExistence = (key: key, future: future);
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
      case ServerReadinessStatus.resolving:
        // Q1 unanswered -- stay wherever we are (the boot screen, on a
        // fresh launch) rather than navigating on a guess we'd have to
        // correct a moment later.
        _wasReady = false;
        return;
      case ServerReadinessStatus.notProvisioned:
        _wasReady = false;
        // Only the very first landing waits -- _hasLeftBootScreen is false
        // exactly once, regardless of what later produces this same status.
        if (!_hasLeftBootScreen) {
          final elapsed = DateTime.now().difference(_bootStartedAt);
          final remaining = kMinFreshInstallBootDuration - elapsed;
          if (remaining > Duration.zero) {
            await Future<void>.delayed(remaining);
          }
          if (generation != _generation) {
            return; // superseded while awaiting
          }
        }
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
    AppLogger.debug('BootRoutingDecider session', {
      'generation': generation,
      'sessionState': session.state.name,
      'latchKey': latchKey.toString(),
      'confirmedLatchKey': _confirmedLatchKey?.toString(),
    });

    final authOk = switch (session.state) {
      AuthSessionState.signedIn => true,
      AuthSessionState.temporarilyUnavailable => latchKey == _confirmedLatchKey,
      AuthSessionState.signedOut => false,
    };

    if (session.state == AuthSessionState.signedIn) {
      _existenceAnswer = null;
      _inFlightExistence = null;
    }

    if (!authOk) {
      final resolver = _instanceExistence;
      if (resolver == null) {
        _navigate(RouteNames.onboardingLogin);
        return;
      }
      final result =
          await _existenceFor((epoch, readiness.instanceId), resolver);
      if (generation != _generation) {
        return; // superseded while awaiting
      }
      switch (result) {
        case InstanceExistenceResult.exists:
          _navigate(RouteNames.onboardingLogin);
        case InstanceExistenceResult.gone:
          _navigate(RouteNames.instanceGone);
        case InstanceExistenceResult.unknown:
          _navigate(RouteNames.instanceUnverifiable);
      }
      return;
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
    if (navigating) {
      _router.goNamed(routeName);
      _hasLeftBootScreen = true;
    }
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
