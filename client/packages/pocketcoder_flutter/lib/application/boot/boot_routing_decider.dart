import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:nav_snapshot/nav_snapshot.dart';
import 'package:pocketcoder_flutter/application/boot/boot_navigation_parts.dart';
import 'package:pocketcoder_flutter/application/boot/boot_route.dart';
import 'package:pocketcoder_flutter/application/boot/boot_routing_policy.dart';
import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_deployment_auth_status.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_instance_existence_resolver.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_server_readiness_check.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/i_harness_auth_repository.dart';

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

  static const Duration kMinFreshInstallBootDuration =
      Duration(milliseconds: 9000);
  static const int kMaxUnknownExistenceRetries = 3;
  static const Duration kUnknownExistenceRetryDelay = Duration(seconds: 2);

  final IServerReadinessCheck _readiness;
  final AuthSessionCoordinator _auth;
  final IHarnessAuthRepository _harness;
  final GoRouter _router;
  final IInstanceExistenceResolver? _instanceExistence;
  final IDeploymentAuthStatus? _deploymentAuthStatus;
  final Duration _unknownExistenceRetryDelay;

  BootNavigationParts? _parts;
  BootRoutingPolicy? _policy;
  NavigationBinding<BootRoute>? _binding;
  Timer? _bootFloorTimer;

  // Set by the timer, never derived from DateTime.now(): flutter_test fakes
  // Timer but not the wall clock, so a clock-reading predicate would never
  // see the floor elapse under test (D9).
  bool _bootFloorPassed = false;

  Future<void> start() async {
    final parts = BootNavigationParts(
      readinessCheck: _readiness,
      authCoordinator: _auth,
      harnessAuthRepository: _harness,
      instanceExistenceResolver: _instanceExistence,
      deploymentAuthStatus: _deploymentAuthStatus,
      unknownExistenceRetryDelay: _unknownExistenceRetryDelay,
      maxUnknownExistenceRetries: kMaxUnknownExistenceRetries,
    );
    final policy = BootRoutingPolicy(
      inputs: parts,
      currentRoute: _currentBootRoute,
      bootFloorElapsed: () => _bootFloorPassed,
      onApplied: _cancelFloorOnceLeft,
    );
    final binding = NavigationBinding<BootRoute>(
      policy: policy,
      target: GoRouterTarget<BootRoute>(
        router: _router,
        routeName: bootRouteName,
        routeFromName: bootRouteFromName,
      ),
    );
    _parts = parts;
    _policy = policy;
    _binding = binding;

    // One deadline, armed once from boot start. The floor is measured from
    // launch, not from whenever notProvisioned happens to arrive: a user who
    // spends eight seconds in `resolving` waits one more second, not nine.
    _bootFloorTimer = Timer(kMinFreshInstallBootDuration, () {
      _bootFloorPassed = true;
      _binding?.evaluate();
    });
    await _readiness.initialize();
    binding.start();
  }

  /// Once the boot screen is behind us the floor can no longer gate
  /// anything, so drop the timer rather than leave it armed for nine
  /// seconds. Under flutter_test a still-pending timer fails the test
  /// outright, and it does so before addTearDown(dispose) ever runs.
  void _cancelFloorOnceLeft() {
    if (!(_policy?.hasLeftBootScreen ?? false)) return;
    _bootFloorTimer?.cancel();
    _bootFloorTimer = null;
  }

  void dispose() {
    _bootFloorTimer?.cancel();
    _binding?.dispose();
    _parts?.dispose();
  }

  Future<void> retryAuth() async {
    final parts = _parts;
    if (parts == null) return;
    parts.authRestore.invalidate();
    parts.existence?.invalidate();
    parts.harness.invalidate();
    _binding?.evaluate();
  }

  BootRoute? _currentBootRoute() {
    try {
      final name = _router.state.name;
      return name == null ? null : bootRouteFromName(name);
    } on StateError {
      return null;
    }
  }
}
