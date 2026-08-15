import 'dart:async';

import 'i_auth_repository.dart';

/// State produced while restoring the locally persisted user session.
enum AuthSessionState {
  signedOut,
  signedIn,
  temporarilyUnavailable,
}

/// Owns silent session restoration and its failure policy.
///
/// Temporary transport failures preserve the local session. Only the auth
/// repository can classify a server response as a definitively invalid session.
class AuthSessionCoordinator {
  AuthSessionCoordinator(
    this._authRepository, {
    this.refreshTimeout = const Duration(seconds: 8),
  });

  final IAuthRepository _authRepository;
  final Duration refreshTimeout;
  Future<AuthRefreshResult>? _refreshInFlight;

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
      return AuthSessionState.signedOut;
    }

    final result = await refresh();

    return switch (result) {
      AuthRefreshResult.refreshed => AuthSessionState.signedIn,
      AuthRefreshResult.temporarilyUnavailable =>
        AuthSessionState.temporarilyUnavailable,
      AuthRefreshResult.invalidSession => AuthSessionState.signedOut,
    };
  }

  Future<AuthRefreshResult> _refreshWithTimeout() {
    return _authRepository.refreshToken().timeout(
          refreshTimeout,
          onTimeout: () => AuthRefreshResult.temporarilyUnavailable,
        );
  }
}
