import 'package:injectable/injectable.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/pocketbase_inspector/i_pocketbase_inspector_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'pocketbase_inspector_state.dart';

@injectable
class PocketbaseInspectorCubit extends AppCubit<PocketbaseInspectorState> {
  PocketbaseInspectorCubit(this._repository)
      : super(const PocketbaseInspectorState());

  final IPocketbaseInspectorRepository _repository;

  Future<void> refresh() async {
    await tryOperation(() async {
      try {
        final stats = await _repository.fetchStats();
        return state.copyWith(stats: stats, status: UiFlowStatus.success);
      } catch (e, stackTrace) {
        logError(
            '🗄️ [PocketbaseInspectorCubit] refresh failed', e, stackTrace);
        rethrow;
      }
    }, emitLoading: true);
  }
}
