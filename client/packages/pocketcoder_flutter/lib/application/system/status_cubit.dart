import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';
import 'status_state.dart';

@injectable
class StatusCubit extends Cubit<StatusState> {
  final IAuthRepository _authRepo;
  StreamSubscription<bool>? _connectionSubscription;

  StatusCubit(this._authRepo) : super(StatusState.initial()) {
    _monitorConnection();
  }

  void _monitorConnection() {
    _connectionSubscription = _authRepo.connectionStatus.listen((isConnected) {
      logInfo(
          '🌐 [StatusCubit] Connectivity changed: ${isConnected ? "CONNECTED" : "DISCONNECTED"}');
      emit(state.copyWith(isConnected: isConnected));
    });
  }

  @override
  Future<void> close() {
    _connectionSubscription?.cancel();
    return super.close();
  }
}
