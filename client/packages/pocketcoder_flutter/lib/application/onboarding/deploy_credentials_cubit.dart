import 'package:flutter_bloc/flutter_bloc.dart';

class DeployCredentialsState {
  const DeployCredentialsState({this.email = '', this.password = ''});

  final String email;
  final String password;
}

class DeployCredentialsCubit extends Cubit<DeployCredentialsState> {
  DeployCredentialsCubit() : super(const DeployCredentialsState());

  void setEmail(String value) => emit(DeployCredentialsState(email: value, password: state.password));
  void setPassword(String value) => emit(DeployCredentialsState(email: state.email, password: value));
}
