import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/notifying_error_box_storage.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'error_inbox_state.dart';

class ErrorInboxCubit extends AppCubit<ErrorInboxState> {
  ErrorInboxCubit({bool watchStorage = false})
      : super(const ErrorInboxState()) {
    final storage = ErrorPrivserverMixin.config?.storage;
    if (watchStorage && storage is NotifyingErrorBoxStorage) {
      _storageChanges = storage.changes.listen((_) => loadErrors());
    }
  }

  StreamSubscription<void>? _storageChanges;

  Future<void> loadErrors() async {
    await tryOperation(() async {
      final errors = await ErrorPrivserver.getUnsentErrors();
      return state.copyWith(
        status: UiFlowStatus.success,
        error: null,
        errors: errors,
      );
    }, emitLoading: true);
  }

  Future<void> deleteError(String id) async {
    final storage = ErrorPrivserverMixin.config?.storage;
    if (storage == null) return;
    await storage.deleteError(id);
    await loadErrors();
  }

  @override
  Future<void> close() async {
    await _storageChanges?.cancel();
    return super.close();
  }
}
