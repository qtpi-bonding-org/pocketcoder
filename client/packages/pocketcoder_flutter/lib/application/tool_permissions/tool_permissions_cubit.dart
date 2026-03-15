import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/hitl/i_hitl_repository.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import "package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart";

part 'tool_permissions_state.dart';
part 'tool_permissions_cubit.freezed.dart';

@injectable
class ToolPermissionsCubit extends AppCubit<ToolPermissionsState> {
  final IHitlRepository _repository;

  ToolPermissionsCubit(this._repository) : super(ToolPermissionsState.initial());

  Future<void> load() async {
    return tryOperation(() async {
      final toolPermissions = await _repository.getToolPermissions();
      return state.copyWith(
        status: UiFlowStatus.success,
        toolPermissions: toolPermissions,
        error: null,
      );
    });
  }

  Future<void> createToolPermission({
    String? agent,
    required String tool,
    required String pattern,
    required String action,
  }) async {
    return tryOperation(() async {
      await _repository.createToolPermission(
        agent: agent,
        tool: tool,
        pattern: pattern,
        action: action,
      );
      await load();
      return createSuccessState();
    });
  }

  Future<void> deleteToolPermission(String id) async {
    return tryOperation(() async {
      await _repository.deleteToolPermission(id);
      await load();
      return createSuccessState();
    });
  }

  Future<void> toggleToolPermission(String id, bool active) async {
    return tryOperation(() async {
      await _repository.toggleToolPermission(id, active);
      await load();
      return createSuccessState();
    });
  }
}
