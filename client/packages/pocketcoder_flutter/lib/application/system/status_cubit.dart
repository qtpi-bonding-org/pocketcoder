import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/network_recovery_signal.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import "package:pocketcoder_flutter/infrastructure/core/logger.dart";
import 'status_state.dart';

@injectable
class StatusCubit extends AppCubit<StatusState> {
  final IAuthRepository _authRepo;
  final NetworkRecoverySignal _networkRecoverySignal;
  StreamSubscription<bool>? _connectionSubscription;

  StatusCubit(this._authRepo, this._networkRecoverySignal)
      : super(StatusState.initial()) {
    _monitorConnection();
  }

  void _monitorConnection() {
    _connectionSubscription = _authRepo.connectionStatus.listen((isConnected) {
      logInfo(
          '🌐 [StatusCubit] Connectivity changed: ${isConnected ? "CONNECTED" : "DISCONNECTED"}');
      if (isConnected) _networkRecoverySignal.notifyRecovered();
      emit(state.copyWith(isConnected: isConnected));
    });
  }

  @override
  Future<void> close() {
    _connectionSubscription?.cancel();
    return super.close();
  }
}
