import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';

class CreateAccountState with UiFlowStateMixin {
  const CreateAccountState({
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

class CreateAccountCubit extends AppCubit<CreateAccountState> {
  CreateAccountCubit() : super(const CreateAccountState());

  void setEmail(String value) => emit(CreateAccountState(
        email: value,
        password: state.password,
        status: state.status,
        error: state.error,
      ));
  void setPassword(String value) => emit(CreateAccountState(
        email: state.email,
        password: value,
        status: state.status,
        error: state.error,
      ));
}
