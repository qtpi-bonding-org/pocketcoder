import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/domain/server_control/server_control_result.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_connection_details_provider.dart';

enum ServerControlOperation {
  restartPocketCoder,
  updatePocketCoder,
  restartNixOs,
  updateNixOs,
  saveBackup,
  restoreBackup,
}

class ServerControlState with UiFlowStateMixin {
  const ServerControlState({
    this.status = UiFlowStatus.idle,
    this.error,
    this.release,
    this.operation,
    this.result,
    this.connectionDetails,
    this.publicKey,
    this.privateKey,
  });

  @override
  final UiFlowStatus status;
  @override
  final Object? error;
  final ServerReleaseStatusSnapshot? release;
  final ServerControlOperation? operation;
  final ServerControlResult? result;
  final IServerConnectionDetailsProvider? connectionDetails;
  final String? publicKey;
  final String? privateKey;

  bool get isBusy => status == UiFlowStatus.loading;

  ServerControlState copyWith({
    UiFlowStatus? status,
    Object? error,
    bool clearError = false,
    ServerReleaseStatusSnapshot? release,
    ServerControlOperation? operation,
    ServerControlResult? result,
    bool clearResult = false,
    IServerConnectionDetailsProvider? connectionDetails,
    String? publicKey,
    String? privateKey,
  }) =>
      ServerControlState(
        status: status ?? this.status,
        error: clearError ? null : error ?? this.error,
        release: release ?? this.release,
        operation: operation ?? this.operation,
        result: clearResult ? null : result ?? this.result,
        connectionDetails: connectionDetails ?? this.connectionDetails,
        publicKey: publicKey ?? this.publicKey,
        privateKey: privateKey ?? this.privateKey,
      );
}
