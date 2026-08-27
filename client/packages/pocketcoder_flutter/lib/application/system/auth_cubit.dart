import 'package:injectable/injectable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import "package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart";
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/support/onboarding_logger.dart';

part 'auth_cubit.freezed.dart';

@freezed
sealed class AuthState with _$AuthState, UiFlowStateMixin {
  const AuthState._();

  const factory AuthState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
    String? savedUrl,
  }) = _AuthState;

  factory AuthState.initial() => const AuthState();
}

@injectable
class AuthCubit extends AppCubit<AuthState> {
  final IAuthRepository _authRepository;

  AuthCubit(this._authRepository) : super(AuthState.initial());

  Future<void> restoreSavedUrl() async {
    String? savedUrl;
    try {
      savedUrl = await _authRepository.getSavedBaseUrl();
    } catch (_) {
      return;
    }
    if (savedUrl != null && !isClosed) {
      emit(state.copyWith(savedUrl: savedUrl));
    }
  }

  Future<void> login(String url, String email, String password) async {
    OnboardingLogger.event('server login started', {
      'email_domain': email.contains('@') ? email.split('@').last : 'invalid',
    });
    // Persisting a candidate URL before it's verified let one typo
    // permanently overwrite the last-known-good saved URL, stranding the
    // user away from their real deployment on the next launch. The
    // previously-saved URL is captured up front so a failed attempt can
    // restore it in memory too, rather than leaving the app pointed at an
    // unverified URL for the rest of the session.
    final previousUrl = await _authRepository.getSavedBaseUrl();
    await tryOperation(() async {
      await _authRepository.updateBaseUrl(url);
      try {
        await _authRepository.verifyServerCompatibility();
        final success = await _authRepository.login(email, password);
        if (!success) {
          throw AuthException.loginFailed();
        }
      } catch (_) {
        if (previousUrl != null) {
          // Best-effort: a revert failure must never mask the real reason
          // this login attempt failed.
          try {
            await _authRepository.updateBaseUrl(previousUrl);
          } catch (_) {}
        }
        rethrow;
      }
      await _authRepository.persistBaseUrl(url);
      OnboardingLogger.event('server login succeeded');
      return createSuccessState();
    });
    if (state.isFailure) {
      OnboardingLogger.event('server login failed', {
        'error': state.error?.toString() ?? 'unknown',
      });
    }
  }

  Future<void> logout() async {
    return tryOperation(() async {
      await _authRepository.logout();
      return createSuccessState();
    });
  }

  /// Unlike [logout], also forgets the saved server URL so the app returns
  /// to a clean connect-to-a-server state rather than re-offering the same
  /// (possibly stale) deployment on the next login attempt.
  Future<void> factoryReset() async {
    return tryOperation(() async {
      await _authRepository.clearSession();
      return createSuccessState();
    });
  }
}
