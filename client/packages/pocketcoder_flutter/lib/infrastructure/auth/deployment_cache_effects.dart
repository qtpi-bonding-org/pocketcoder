import 'dart:async';

import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';

/// Clears the disposable PocketBase cache when the active deployment changes.
///
/// The cache is deliberately not partitioned by deployment: a destroy/recreate
/// points the same user at a new source of truth, so retaining old rows would
/// be misleading. The package database API preserves the cached schema while
/// clearing records, responses, and file blobs.
class DeploymentCacheEffects {
  DeploymentCacheEffects(this._coordinator, this._pocketBase);

  final AuthSessionCoordinator _coordinator;
  final PocketBase _pocketBase;
  StreamSubscription<AuthSessionSnapshot>? _subscription;
  String? _previousBaseUrl;

  void start() {
    if (_subscription != null) return;
    _subscription = _coordinator.sessionChanges.listen(_onSnapshot);
  }

  Future<void> _onSnapshot(AuthSessionSnapshot snapshot) async {
    final current = snapshot.baseUrl;
    final previous = _previousBaseUrl;
    _previousBaseUrl = current;
    if (previous == null || current == null || previous == current) return;

    final client = _pocketBase;
    if (client is $PocketBase) {
      await client.db.clearAllData();
    }
  }
}
