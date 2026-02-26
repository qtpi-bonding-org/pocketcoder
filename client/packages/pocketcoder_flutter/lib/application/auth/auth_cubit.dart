import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/auth/i_oauth_service.dart';
import 'package:pocketcoder_flutter/domain/models/oauth_token.dart';
import 'package:pocketcoder_flutter/domain/storage/i_secure_storage.dart';
import '../../support/extensions/cubit_ui_flow_extension.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

import 'auth_state.dart';

/// Cubit for managing authentication state and operations
@injectable
class AuthCubit extends AppCubit<AuthState> {
  final IOAuthService _authService;
  final ISecureStorage _secureStorage;

  AuthCubit(
    this._authService,
    this._secureStorage,
  ) : super(AuthState.initial());

  /// Initiates OAuth authentication flow
  Future<void> authenticate() async {
    return tryOperation(() async {
      await _authService.authenticate();

      // Get the access token to confirm successful authentication
      final accessToken = await _authService.getAccessToken();
      final refreshToken = await _secureStorage.getRefreshToken();
      final expiresAt = await _secureStorage.getTokenExpiration();

      final token = OAuthToken(
        accessToken: accessToken,
        refreshToken: refreshToken ?? '',
        expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 1)),
        scopes: _authService.requiredScopes,
      );

      return state.copyWith(
        status: UiFlowStatus.success,
        token: token,
        isAuthenticated: true,
      );
    }, emitLoading: true);
  }

  /// Logs out the user by clearing all stored tokens
  Future<void> logout() async {
    return tryOperation(() async {
      await _authService.logout();

      return AuthState.initial();
    });
  }

  /// Checks the current authentication status
  Future<void> checkAuthStatus() async {
    return tryOperation(() async {
      try {
        final accessToken = await _authService.getAccessToken();
        final refreshToken = await _secureStorage.getRefreshToken();
        final expiresAt = await _secureStorage.getTokenExpiration();

        if (accessToken.isNotEmpty) {
          final token = OAuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken ?? '',
            expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 1)),
            scopes: _authService.requiredScopes,
          );

          return state.copyWith(
            status: UiFlowStatus.success,
            token: token,
            isAuthenticated: true,
          );
        }

        return state.copyWith(
          status: UiFlowStatus.success,
          isAuthenticated: false,
        );
      } catch (e) {
        return state.copyWith(
          status: UiFlowStatus.success,
          isAuthenticated: false,
        );
      }
    });
  }
}