import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

import 'package:pocketcoder_flutter/domain/pocketcoder_update/i_pocketcoder_update_service.dart';

import 'pocketcoder_update_state.dart';

/// Runs the user-initiated PocketCoder update: SSH in as root, run the verified
/// release updater, and show its output. Nothing here runs unless a user explicitly calls [update] --
/// no background timer, no auto-polling.
class PocketCoderUpdateCubit extends AppCubit<PocketCoderUpdateState> {
  final IPocketCoderUpdateService _service;

  PocketCoderUpdateCubit(this._service)
      : super(PocketCoderUpdateState.initial());

  Future<void> load() async {
    return tryOperation(() async {
      final preview = await _service.inspect();
      return state.copyWith(
        status: UiFlowStatus.success,
        preview: preview,
      );
    }, emitLoading: true);
  }

  Future<void> update(String instanceId) async {
    return tryOperation(() async {
      final result = await _service.updatePocketCoder(instanceId: instanceId);

      return state.copyWith(
        status: UiFlowStatus.success,
        result: result,
      );
    }, emitLoading: true);
  }

  void confirmUpgrade() => emit(state.copyWith(upgradeConfirmed: true));

  void reset() => emit(PocketCoderUpdateState.initial());
}
