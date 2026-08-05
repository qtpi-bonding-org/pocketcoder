import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/tool_permissions/i_tool_permission_repository.dart';
import "package:pocketcoder_flutter/infrastructure/core/logger.dart";
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_capture.dart';
import 'tool_permissions_state.dart';

@injectable
class ToolPermissionsCubit extends Cubit<ToolPermissionsState> {
  final IToolPermissionRepository _repository;
  StreamSubscription? _subscription;

  ToolPermissionsCubit(this._repository)
      : super(const ToolPermissionsState.initial());

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  void watchRules() {
    emit(const ToolPermissionsState.loading());
    _subscription?.cancel();
    _subscription = _repository.watchRules().listen(
      (rules) {
        emit(ToolPermissionsState.loaded(rules));
      },
      onError: (e) {
        unawaited(pocketCoderDiagnosticCapture.capture(
            error: e, source: 'ToolPermissionsCubit', operation: 'watchRules'));
        logError('ToolPermissions: Failed to watch rules', e);
        emit(ToolPermissionsState.error(e.toString()));
      },
    );
  }

  Future<void> updateAction(String id, String action) async {
    try {
      await _repository.updateAction(id, action);
    } catch (e) {
      await pocketCoderDiagnosticCapture.capture(
          error: e, source: 'ToolPermissionsCubit', operation: 'updateAction');
      logError('ToolPermissions: Failed to update action', e);
      emit(ToolPermissionsState.error(e.toString()));
    }
  }

  Future<void> setActive(String id, bool active) async {
    try {
      await _repository.setActive(id, active);
    } catch (e) {
      await pocketCoderDiagnosticCapture.capture(
          error: e, source: 'ToolPermissionsCubit', operation: 'setActive');
      logError('ToolPermissions: Failed to set active', e);
      emit(ToolPermissionsState.error(e.toString()));
    }
  }

  Future<void> createRule(
      {required String tool, required String action}) async {
    try {
      await _repository.createRule(tool: tool, action: action);
    } catch (e) {
      await pocketCoderDiagnosticCapture.capture(
          error: e, source: 'ToolPermissionsCubit', operation: 'createRule');
      logError('ToolPermissions: Failed to create rule', e);
      emit(ToolPermissionsState.error(e.toString()));
    }
  }
}
