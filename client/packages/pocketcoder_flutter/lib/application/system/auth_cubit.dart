import 'package:injectable/injectable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/auth/i_auth_repository.dart';
import '../../support/extensions/cubit_ui_flow_extension.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

part 'auth_cubit.freezed.dart';

@freezed
class AuthState with _$AuthState implements IUiFlowState {
  const AuthState._();

  const factory AuthState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
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

  Future<void> login(String email, String password) async {
    return tryOperation(() async {
      final success = await _authRepository.login(email, password);
      if (!success) {
        throw 'ACCESS DENIED. CHECK CREDENTIALS.';
      }
      return createSuccessState();
    });
  }
}
