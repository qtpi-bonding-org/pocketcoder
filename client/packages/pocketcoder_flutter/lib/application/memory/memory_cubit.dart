import 'package:injectable/injectable.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/memory/i_memory_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'memory_state.dart';

@injectable
class MemoryCubit extends AppCubit<MemoryState> {
  MemoryCubit(this._repository) : super(const MemoryState());

  final IMemoryRepository _repository;

  Future<void> refresh() async {
    await tryOperation(() async {
      try {
        final stats = await _repository.fetchStats();
        return state.copyWith(stats: stats, status: UiFlowStatus.success);
      } catch (e, stackTrace) {
        logError('🧠 [MemoryCubit] refresh failed', e, stackTrace);
        rethrow;
      }
    }, emitLoading: true);
  }
}
