import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/hitl/i_hitl_repository.dart';
import 'package:pocketcoder_flutter/domain/models/whitelist_action.dart';
import 'package:pocketcoder_flutter/domain/models/whitelist_target.dart';
import '../../support/extensions/cubit_ui_flow_extension.dart';

part 'whitelist_state.dart';
part 'whitelist_cubit.freezed.dart';

@injectable
class WhitelistCubit extends AppCubit<WhitelistState> {
  final IHitlRepository _repository;

  WhitelistCubit(this._repository) : super(WhitelistState.initial());

  Future<void> load() async {
    return tryOperation(() async {
      final targets = await _repository.getTargets();
      final actions = await _repository.getActions();
      return state.copyWith(
        status: UiFlowStatus.success,
        targets: targets,
        actions: actions,
        error: null,
      );
    });
  }

  Future<void> createTarget(String name, String pattern) async {
    return tryOperation(() async {
      await _repository.createTarget(name, pattern);
      await load();
      return createSuccessState();
    });
  }

  Future<void> deleteTarget(String id) async {
    return tryOperation(() async {
      await _repository.deleteTarget(id);
      await load();
      return createSuccessState();
    });
  }

  Future<void> createAction(
    String permission, {
    String kind = 'pattern',
    String? value,
  }) async {
    return tryOperation(() async {
      await _repository.createAction(permission, kind: kind, value: value);
      await load();
      return createSuccessState();
    });
  }

  Future<void> deleteAction(String id) async {
    return tryOperation(() async {
      await _repository.deleteAction(id);
      await load();
      return createSuccessState();
    });
  }

  Future<void> toggleAction(String id, bool active) async {
    return tryOperation(() async {
      await _repository.toggleAction(id, active);
      await load();
      return createSuccessState();
    });
  }
}
