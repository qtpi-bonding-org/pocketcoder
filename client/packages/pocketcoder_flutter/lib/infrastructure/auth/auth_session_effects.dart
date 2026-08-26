import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/domain/notifications/push_service.dart';

/// Applies device-facing effects for changes in the authenticated session.
///
/// Effects are deliberately best effort relative to authentication. A failed
/// sign-in effect is not recorded as handled, so a later signed-in snapshot can
/// retry it. One queue also makes deployment/user changes deterministic.
class AuthSessionEffects {
  AuthSessionEffects(
    this._coordinator,
    this._billingService,
    this._pushService,
  );

  final AuthSessionCoordinator _coordinator;
  final BillingService _billingService;
  final PushService _pushService;
  Future<void> _queue = Future<void>.value();
  StreamSubscription<AuthSessionSnapshot>? _subscription;
  final Set<String> _scheduledIdentities = <String>{};
  final Set<String> _handledIdentities = <String>{};
  bool _signedOutScheduled = false;

  /// Starts listening, including the coordinator's replayed current snapshot.
  void start() {
    if (_subscription != null) return;
    _subscription = _coordinator.sessionChanges.listen(_enqueue);
  }

  void _enqueue(AuthSessionSnapshot snapshot) {
    if (snapshot.state == AuthSessionState.signedIn &&
        snapshot.userId != null) {
      final userId = snapshot.userId;
      final identity = _identityFor(snapshot);
      if (_handledIdentities.contains(identity) ||
          _scheduledIdentities.contains(identity)) {
        return;
      }
      _scheduledIdentities.add(identity);
      _queue = _queue.then((_) async {
        try {
          if (userId == null) return;
          await _billingService.identify(userId);
          await _pushService.syncAuthenticatedDevice();
          // This is intentionally after both calls: failures remain retryable.
          _handledIdentities.add(identity);
        } catch (error, stack) {
          _scheduledIdentities.remove(identity);
          debugPrint('Auth session effects sign-in failed: $error');
          debugPrint('$stack');
        }
      });
      return;
    }

    if (snapshot.state == AuthSessionState.signedOut && !_signedOutScheduled) {
      _signedOutScheduled = true;
      _handledIdentities.clear();
      _queue = _queue.then((_) async {
        try {
          await _pushService.unregisterAuthenticatedDevice();
          await _billingService.reset();
        } catch (error, stack) {
          debugPrint('Auth session effects sign-out failed: $error');
          debugPrint('$stack');
        }
      });
    } else if (snapshot.state == AuthSessionState.signedIn) {
      _signedOutScheduled = false;
    }
  }

  String _identityFor(AuthSessionSnapshot snapshot) {
    return '${snapshot.userId}|${snapshot.baseUrl ?? ''}';
  }
}
