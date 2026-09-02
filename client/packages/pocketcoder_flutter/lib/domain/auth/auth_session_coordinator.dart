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
    this.refreshTimeout = const Duration(seconds: 2),
    this.maxRefreshAttempts = 3,
    Future<void> Function(int attempt)? refreshRetryDelay,
  }) : _refreshRetryDelay = refreshRetryDelay ?? _defaultRefreshRetryDelay {
    // Subscribe before taking the initial snapshot. This prevents a change
    // between subscription and the first replay from being missed.
    _authRepository.authChanges.listen((_) {
      _publish(_snapshotFor(
        _authRepository.isAuthenticated
            ? AuthSessionState.signedIn
            : AuthSessionState.signedOut,
      ));
    });
    _latestSnapshot = _snapshotFor(
      _authRepository.isAuthenticated
          ? AuthSessionState.signedIn
          : AuthSessionState.signedOut,
    );
  }

  static Future<void> _defaultRefreshRetryDelay(int attempt) =>
      Future<void>.delayed(const Duration(seconds: 2));

  final IAuthRepository _authRepository;
  final Duration refreshTimeout;
  final int maxRefreshAttempts;
  final Future<void> Function(int attempt) _refreshRetryDelay;
  Future<AuthRefreshResult>? _refreshInFlight;
  late AuthSessionSnapshot _latestSnapshot;
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
      AuthRefreshResult.temporarilyUnavailable =>
        AuthSessionState.temporarilyUnavailable,
      AuthRefreshResult.invalidSession => AuthSessionState.signedOut,
    };
    _publish(_snapshotFor(state));
    return state;
  }

  Future<AuthRefreshResult> _refreshWithTimeout() async {
    for (var attempt = 1; attempt <= maxRefreshAttempts; attempt++) {
      final result = await _authRepository.refreshToken().timeout(
            refreshTimeout,
            onTimeout: () => AuthRefreshResult.temporarilyUnavailable,
          );
      // Only a timeout/transient failure is worth retrying -- a definitive
      // result (refreshed or invalidSession) should return immediately.
      if (result != AuthRefreshResult.temporarilyUnavailable ||
          attempt == maxRefreshAttempts) {
        return result;
      }
      await _refreshRetryDelay(attempt);
    }
    return AuthRefreshResult.temporarilyUnavailable;
  }
}
