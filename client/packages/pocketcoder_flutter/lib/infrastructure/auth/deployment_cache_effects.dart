import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';

/// Clears the disposable PocketBase cache when the active deployment changes.
///
/// The cache is deliberately not partitioned by deployment: a destroy/recreate
/// points the same user at a new source of truth, so retaining old rows would
/// be misleading. The package database API preserves the cached schema while
/// clearing records, responses, and file blobs.
class DeploymentCacheEffects {
  DeploymentCacheEffects(
    this._coordinator,
    this._pocketBase, {
    Future<void> Function()? clearCache,
  }) : _clearCache = clearCache;

  final AuthSessionCoordinator _coordinator;
  final PocketBase _pocketBase;
  final Future<void> Function()? _clearCache;
  Future<void> _queue = Future<void>.value();
  StreamSubscription<AuthSessionSnapshot>? _subscription;
  String? _previousBaseUrl;
  String? _scheduledTargetBaseUrl;

  void start() {
    if (_subscription != null) return;
    _subscription = _coordinator.sessionChanges.listen(_enqueue);
  }

  void _enqueue(AuthSessionSnapshot snapshot) {
    final current = snapshot.baseUrl;
    final previous = _previousBaseUrl;
    if (current == null) {
      // A temporarily unavailable session must invalidate the baseline.  The
      // next usable snapshot is therefore treated as the new baseline rather
      // than as a deployment transition.
      _previousBaseUrl = null;
      return;
    }
    if (previous == null) {
      // The first usable snapshot establishes the baseline without clearing.
      _previousBaseUrl = current;
      return;
    }
    if (previous == current) return;
    if (_scheduledTargetBaseUrl == current) return;

    final clearCache = _clearCache;
    final client = _pocketBase;
    if (clearCache == null && client is! $PocketBase) return;

    // Keep this guard separate from _previousBaseUrl: the latter represents
    // the last successfully cleared deployment, while this represents work
    // already queued for the current transition.
    _scheduledTargetBaseUrl = current;
    _queue = _queue.then((_) async {
      try {
        if (clearCache != null) {
          await clearCache();
        } else {
          await (client as $PocketBase).db.clearAllData();
        }
        _previousBaseUrl = current;
        if (_scheduledTargetBaseUrl == current) {
          _scheduledTargetBaseUrl = null;
        }
      } catch (error, stack) {
        // Leave _previousBaseUrl unchanged so a later snapshot can retry.
        if (_scheduledTargetBaseUrl == current) {
          _scheduledTargetBaseUrl = null;
        }
        debugPrint('Deployment cache effects clear failed: $error');
        debugPrint('$stack');
      }
    });
  }
}
