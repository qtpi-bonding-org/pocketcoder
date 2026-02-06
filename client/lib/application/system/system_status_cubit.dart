import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:test_app/domain/auth/i_auth_repository.dart';
import 'system_status_state.dart';

@injectable
class SystemStatusCubit extends Cubit<SystemStatusState> {
  final IAuthRepository _authRepo;
  StreamSubscription<bool>? _connectionSubscription;

  SystemStatusCubit(this._authRepo) : super(SystemStatusState.initial()) {
    _monitorConnection();
  }

  void _monitorConnection() {
    _connectionSubscription = _authRepo.connectionStatus.listen((isConnected) {
      emit(state.copyWith(isConnected: isConnected));
    });
  }

  @override
  Future<void> close() {
    _connectionSubscription?.cancel();
    return super.close();
  }
}
