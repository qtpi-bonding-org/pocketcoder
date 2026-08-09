import 'package:injectable/injectable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import "package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart";
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/support/onboarding_logger.dart';

part 'auth_cubit.freezed.dart';

@freezed
sealed class AuthState with _$AuthState implements IUiFlowState {
  const AuthState._();

  const factory AuthState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
    String? savedUrl,
  }) = _AuthState;

  factory AuthState.initial() => const AuthState();

  @override
  bool get isIdle => status == UiFlowStatus.idle;
  @override
  bool get isLoading => status == UiFlowStatus.loading;
  @override
  bool get isSuccess => status == UiFlowStatus.success;
  @override
  bool get isFailure => status == UiFlowStatus.failure;
  @override
  bool get hasError => error != null;
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
    await tryOperation(() async {
      await _authRepository.updateBaseUrl(url);
      final success = await _authRepository.login(email, password);
      if (!success) {
        throw 'ACCESS DENIED. CHECK CREDENTIALS.';
      }
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
}
