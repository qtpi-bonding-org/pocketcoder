import 'dart:async';

import 'i_auth_repository.dart';

/// State produced while restoring the locally persisted user session.
enum AuthSessionState {
  signedOut,
  signedIn,
  temporarilyUnavailable,
}

/// The session identity, including the deployment that owns its token.
class AuthSessionSnapshot {
  const AuthSessionSnapshot({
    required this.state,
    required this.userId,
    required this.baseUrl,
  });

  final AuthSessionState state;
  final String? userId;
  final String? baseUrl;
}

/// Owns silent session restoration and its failure policy.
class AuthSessionCoordinator {
  AuthSessionCoordinator(
    this._authRepository, {
    this.refreshTimeout = const Duration(seconds: 3),
  }) {
    // Subscribe before taking the initial snapshot. This prevents a change
    // between subscription and the first replay from being missed.
    _authRepository.authChanges.listen((_) {
      final signedIn = _authRepository.isAuthenticated;
      if (!signedIn) {
        _liveSignIn = false;
      } else if (_latestSnapshot.state == AuthSessionState.signedOut) {
        _liveSignIn = true;
      }
      _publish(_snapshotFor(
        signedIn ? AuthSessionState.signedIn : AuthSessionState.signedOut,
      ));
    });
    _latestSnapshot = _snapshotFor(
      _authRepository.isAuthenticated
          ? AuthSessionState.signedIn
          : AuthSessionState.signedOut,
    );
  }

  final IAuthRepository _authRepository;
  final Duration refreshTimeout;
  Future<AuthRefreshResult>? _refreshInFlight;
  late AuthSessionSnapshot _latestSnapshot;
  // Server-confirmed in this process; an unavailable refresh must not demote it.
  bool _liveSignIn = false;
  final StreamController<AuthSessionSnapshot> _liveChanges =
      StreamController<AuthSessionSnapshot>.broadcast();

  AuthSessionSnapshot get current => _latestSnapshot;

  /// A broadcast stream replaying the latest snapshot to each listener.
  Stream<AuthSessionSnapshot> get sessionChanges => Stream.multi(
        (multi) {
          // Attach first, then replay. A synchronous source change cannot fall
          // through the gap between these operations.
          final subscription = _liveChanges.stream.listen(multi.add);
          scheduleMicrotask(() => multi.add(_latestSnapshot));
          multi.onCancel = subscription.cancel;
        },
        isBroadcast: true,
      );

  AuthSessionSnapshot _snapshotFor(AuthSessionState state) {
    return AuthSessionSnapshot(
      state: state,
      userId: state == AuthSessionState.signedOut
          ? null
          : _authRepository.currentUserId,
      baseUrl: _authRepository.currentBaseUrl,
    );
  }

  void _publish(AuthSessionSnapshot snapshot) {
    _latestSnapshot = snapshot;
    _liveChanges.add(snapshot);
  }

  /// Shares one refresh operation across simultaneous 401 responses.
  Future<AuthRefreshResult> refresh() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    final refresh = _refreshWithTimeout();
    _refreshInFlight = refresh;
    refresh.whenComplete(() {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
      }
    });
    return refresh;
  }

  Future<AuthSessionState> restore() async {
    if (!_authRepository.isAuthenticated) {
      _publish(_snapshotFor(AuthSessionState.signedOut));
      return AuthSessionState.signedOut;
    }

    final result = await refresh();
    final state = switch (result) {
      AuthRefreshResult.refreshed => AuthSessionState.signedIn,
      AuthRefreshResult.temporarilyUnavailable when _liveSignIn =>
        AuthSessionState.signedIn,
      AuthRefreshResult.temporarilyUnavailable =>
        AuthSessionState.temporarilyUnavailable,
      AuthRefreshResult.invalidSession => AuthSessionState.signedOut,
    };
    if (state == AuthSessionState.signedOut) _liveSignIn = false;
    _publish(_snapshotFor(state));
    return state;
  }

  Future<AuthRefreshResult> _refreshWithTimeout() {
    return _authRepository.refreshToken().timeout(
          refreshTimeout,
          onTimeout: () => AuthRefreshResult.temporarilyUnavailable,
        );
  }
}
