import 'dart:async';

import 'package:pocketcoder_flutter/domain/auth/auth_session_coordinator.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';

class ProviderCatalogWarmup {
  ProviderCatalogWarmup(this._coordinator, this._repo);

  final AuthSessionCoordinator _coordinator;
  final IProviderRepository _repo;
  StreamSubscription<AuthSessionSnapshot>? _subscription;

  void start() {
    if (_subscription != null) return;
    _subscription = _coordinator.sessionChanges.listen(_onSnapshot);
  }

  void _onSnapshot(AuthSessionSnapshot snapshot) {
    if (snapshot.state != AuthSessionState.signedIn) return;
    unawaited(_warm(_repo.fetchModels));
    unawaited(_warm(_repo.fetchHarnessModels));
  }

  // getFullList can throw synchronously (e.g. AuthException on an empty
  // token), not just reject its Future, so each fetch needs its own
  // isolated try/catch -- one failing must not stop the sibling from firing.
  Future<void> _warm(Future<Object?> Function() fetch) async {
    try {
      await fetch();
    } catch (_) {}
  }
}
