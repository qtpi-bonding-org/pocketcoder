import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';

class DeployCredentialsState with UiFlowStateMixin {
  const DeployCredentialsState({
    this.email = '',
    this.password = '',
    this.status = UiFlowStatus.idle,
    this.error,
  });

  final String email;
  final String password;
  @override
  final UiFlowStatus status;
  @override
  final Object? error;
}

class DeployCredentialsCubit extends AppCubit<DeployCredentialsState> {
  DeployCredentialsCubit() : super(const DeployCredentialsState());

  void setEmail(String value) => emit(DeployCredentialsState(
        email: value,
        password: state.password,
        status: state.status,
        error: state.error,
      ));
  void setPassword(String value) => emit(DeployCredentialsState(
        email: state.email,
        password: value,
        status: state.status,
        error: state.error,
      ));
}
