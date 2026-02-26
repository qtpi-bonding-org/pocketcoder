import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_aeroform/domain/models/oauth_token.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

part 'auth_state.freezed.dart';

/// Authentication state for the mobile deployment feature
@freezed
class AuthState with _$AuthState implements IUiFlowState {
  const AuthState._();

  const factory AuthState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    Object? error,
    OAuthToken? token,
    bool? isAuthenticated,
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