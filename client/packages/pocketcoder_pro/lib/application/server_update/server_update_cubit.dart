import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

import 'package:pocketcoder_pro/domain/server_update/i_server_update_service.dart';

import 'server_update_state.dart';

/// Runs the user-initiated server update: SSH in as root, run the verified
/// release updater, and show its output. Nothing here runs unless a user explicitly calls [update] --
/// no background timer, no auto-polling.
class ServerUpdateCubit extends AppCubit<ServerUpdateState> {
  final IServerUpdateService _service;

  ServerUpdateCubit(this._service) : super(ServerUpdateState.initial());

  Future<void> update(String instanceId) async {
    return tryOperation(() async {
      final result = await _service.updateServer(instanceId: instanceId);

      return state.copyWith(
        status: UiFlowStatus.success,
        result: result,
      );
    }, emitLoading: true);
  }

  void reset() => emit(ServerUpdateState.initial());
}
