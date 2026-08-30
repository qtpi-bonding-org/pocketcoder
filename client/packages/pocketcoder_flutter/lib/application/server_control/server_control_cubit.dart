import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';
import 'package:pocketcoder_flutter/domain/security/i_local_auth_gate.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_control_service.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_connection_details_provider.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'server_control_state.dart';

@injectable
class ServerControlCubit extends AppCubit<ServerControlState> {
  ServerControlCubit(
    this._service,
    this._localAuthGate, [
    IServerConnectionDetailsProvider? connectionDetails,
  ]) : super(ServerControlState(connectionDetails: connectionDetails));

  final IServerControlService _service;
  final ILocalAuthGate _localAuthGate;

  Future<void> inspectRelease() async {
    await tryOperation(() async {
      final release = await _service.inspectRelease();
      return state.copyWith(
        status: UiFlowStatus.success,
        release: release,
        clearError: true,
      );
    }, emitLoading: true);
  }

  static const _releaseRefreshRetryDelay = Duration(seconds: 1);

  Future<void> run({
    required ServerControlOperation operation,
    required String instanceId,
  }) async {
    await tryOperation(() async {
      final result = switch (operation) {
        ServerControlOperation.restartPocketCoder =>
          await _service.restartPocketCoder(instanceId: instanceId),
        ServerControlOperation.updatePocketCoder =>
          await _service.updatePocketCoder(instanceId: instanceId),
        ServerControlOperation.restartNixOs =>
          await _service.restartNixOs(instanceId: instanceId),
        ServerControlOperation.updateNixOs =>
          await _service.updateNixOs(instanceId: instanceId),
        ServerControlOperation.saveBackup =>
          await _service.saveBackup(instanceId: instanceId),
      };
      return state.copyWith(
        status: UiFlowStatus.success,
        operation: operation,
        result: result,
        clearError: true,
      );
    }, emitLoading: true);
    if (state.status == UiFlowStatus.success &&
        operation != ServerControlOperation.saveBackup) {
      await _refreshReleaseAfterOperation();
    }
  }

  /// A restart/update op's own health check (server-side, per the release
  /// manager) already confirms the new release before it reports success --
  /// this just re-reads that confirmed state. One retry covers the app's own
  /// HTTP connection, separate from that health check, resetting while
  /// PocketBase bounces. A failure here (including the retry) leaves the
  /// last-known [ServerControlState.release] in place rather than surfacing
  /// an error banner for an operation that already succeeded.
  Future<void> _refreshReleaseAfterOperation() async {
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) await Future<void>.delayed(_releaseRefreshRetryDelay);
      try {
        final release = await _service.inspectRelease();
        emit(state.copyWith(release: release));
        return;
      } on Object {
        // Best-effort; fall through to the retry, or give up silently.
      }
    }
  }

  Future<void> loadPublicKey(String instanceId) async {
    try {
      final publicKey = await _service.readPublicKey(instanceId: instanceId);
      emit(state.copyWith(publicKey: publicKey));
    } on Object {
      // A failed key read shouldn't block the control buttons -- and this
      // is fire-and-forget, so an uncaught error here becomes unhandled.
    }
  }

  /// Thin passthrough so widgets can gate a local-only reveal (e.g. the
  /// admin password, which is already in [state.connectionDetails] and
  /// needs no fetch) without reaching into DI directly.
  Future<bool> confirmLocalAuth({required String reason}) =>
      _localAuthGate.authenticate(reason: reason);

  Future<void> revealPrivateKey({
    required String instanceId,
    required String authReason,
  }) async {
    if (!await _localAuthGate.authenticate(reason: authReason)) return;
    try {
      final privateKey = await _service.readPrivateKey(instanceId: instanceId);
      emit(state.copyWith(privateKey: privateKey));
    } on Object {
      // Fire-and-forget, matching loadPublicKey: a failed read shouldn't
      // block the control buttons.
    }
  }

  static RootSshCommand commandFor(ServerControlOperation operation) =>
      switch (operation) {
        ServerControlOperation.restartPocketCoder =>
          RootSshCommand.restartPocketCoder,
        ServerControlOperation.updatePocketCoder =>
          RootSshCommand.updatePocketCoder,
        ServerControlOperation.restartNixOs => RootSshCommand.restartNixOs,
        ServerControlOperation.updateNixOs => RootSshCommand.updateNixOs,
        ServerControlOperation.saveBackup => RootSshCommand.saveBackup,
      };
}
