import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_instance_existence_resolver.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deployment_auth_status.dart';
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
    IDeploymentAuthStatus? deploymentAuthStatus,
    Duration unknownExistenceRetryDelay = kUnknownExistenceRetryDelay,
  })  : _readiness = readinessCheck,
        _auth = authCoordinator,
        _harness = harnessAuthRepository,
        _router = router,
        _instanceExistence = instanceExistenceResolver,
        _deploymentAuthStatus = deploymentAuthStatus,
        _unknownExistenceRetryDelay = unknownExistenceRetryDelay;

  /// Must equal BootScreen's own scripted timeline length (2.5s + 6.5s),
  /// since nothing here observes BootScreen's actual animation state.
  static const Duration kMinFreshInstallBootDuration =
      Duration(milliseconds: 9000);

  /// A cloud-provider existence check is a last-resort fallback for a flaky
  /// auth refresh, not an authority on whether the deployment is reachable
  /// -- so an [InstanceExistenceResult.unknown] (the provider API itself
  /// failed/timed out/lacks a token) gets a few retries before it's treated
  /// as decisive enough to show instanceUnverifiable.
  static const int kMaxUnknownExistenceRetries = 3;
  static const Duration kUnknownExistenceRetryDelay = Duration(seconds: 2);

  final IServerReadinessCheck _readiness;
  final AuthSessionCoordinator _auth;
  final IHarnessAuthRepository _harness;
  final GoRouter _router;
  final IInstanceExistenceResolver? _instanceExistence;
  final IDeploymentAuthStatus? _deploymentAuthStatus;
  final Duration _unknownExistenceRetryDelay;

  StreamSubscription<ServerReadinessSnapshot>? _readinessSub;
  StreamSubscription<AuthSessionSnapshot>? _authSub;
  StreamSubscription<void>? _deploymentAuthSub;
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
  String? _lastDeployProgressRoute;
  _ExistenceKey? _unknownRetryKey;
  int _unknownRetryCount = 0;
  Timer? _unknownRetryTimer;

  Future<void> start() async {
    _readinessSub = _readiness.readinessChanges.listen((_) => _reconcile());
    _authSub = _auth.sessionChanges.listen((_) => _reconcile());
    _deploymentAuthSub =
        _deploymentAuthStatus?.changes.listen((_) => _reconcile());
    await _readiness.initialize();
    await _reconcile();
  }

  void dispose() {
    _readinessSub?.cancel();
    _authSub?.cancel();
    _deploymentAuthSub?.cancel();
    _unknownRetryTimer?.cancel();
  }

  Future<void> retryAuth() async {
    _existenceAnswer = null;
    _restoredEpoch = null;
    _unknownRetryKey = null;
    _unknownRetryCount = 0;
    _unknownRetryTimer?.cancel();
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
        _navigateDeployPhase(RouteNames.onboarding);
        return;
      case ServerReadinessStatus.provisioning:
      case ServerReadinessStatus.resumeUnrecoverable:
        _wasReady = false;
        _navigateDeployPhase(RouteNames.deploymentProgress);
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

    final deploymentAuth = _deploymentAuthStatus?.current;
    if (deploymentAuth != null &&
        deploymentAuth.instanceId == readiness.instanceId &&
        (deploymentAuth.phase == DeploymentAuthPhase.waitingForCredentials ||
            deploymentAuth.phase == DeploymentAuthPhase.signingIn)) {
      // In-flight auto-login makes this auth reading transient.
      return;
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
      final existenceKey = (epoch, readiness.instanceId);
      final result = await _existenceFor(existenceKey, resolver);
      if (generation != _generation) {
        return; // superseded while awaiting
      }
      switch (result) {
        case InstanceExistenceResult.exists:
          _unknownRetryKey = null;
          _unknownRetryCount = 0;
          _navigate(RouteNames.onboardingLogin);
        case InstanceExistenceResult.gone:
          _unknownRetryKey = null;
          _unknownRetryCount = 0;
          _navigate(RouteNames.instanceGone);
        case InstanceExistenceResult.unknown:
          if (_unknownRetryKey != existenceKey) {
            _unknownRetryKey = existenceKey;
            _unknownRetryCount = 0;
          }
          _unknownRetryCount++;
          if (_unknownRetryCount < kMaxUnknownExistenceRetries) {
            AppLogger.debug('BootRoutingDecider existence unknown -- retrying', {
              'generation': generation,
              'attempt': _unknownRetryCount,
            });
            _unknownRetryTimer?.cancel();
            _unknownRetryTimer = Timer(_unknownExistenceRetryDelay, () {
              // Cleared here, not when scheduling: an unrelated reconcile
              // (readiness/auth change) firing before this timer must still
              // see the cached unknown answer, not force its own extra
              // resolver call.
              _existenceAnswer = null;
              if (generation == _generation) unawaited(_reconcile());
            });
          } else {
            _navigate(RouteNames.instanceUnverifiable);
          }
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

  // Only set on an actual deploymentProgress push, not on onboarding --
  // onboarding's own forward navigation must never poison this guard.
  void _navigateDeployPhase(String routeName) {
    final current = _currentRouteName();
    if (_lastDeployProgressRoute != null &&
        current != _lastDeployProgressRoute) {
      AppLogger.debug('BootRoutingDecider deploy-phase nav suppressed', {
        'requested': routeName,
        'current': current,
        'lastDeployProgressRoute': _lastDeployProgressRoute,
      });
      return;
    }
    _navigate(routeName);
    if (routeName == RouteNames.deploymentProgress) {
      _lastDeployProgressRoute = routeName;
    } else if (routeName == RouteNames.onboarding) {
      // notProvisioned means no attempt exists at all -- the guard has
      // nothing left to protect, and must not suppress a later, unrelated
      // attempt's push to deploymentProgress.
      _lastDeployProgressRoute = null;
    }
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
