import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/release/i_server_release_status_service.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';

class ReleaseStatusState implements IUiFlowState {
  const ReleaseStatusState({
    this.status = UiFlowStatus.idle,
    this.error,
    this.snapshot,
    this.updateNoticeDismissed = false,
  });

  @override
  final UiFlowStatus status;
  @override
  final Object? error;
  final ServerReleaseStatusSnapshot? snapshot;
  final bool updateNoticeDismissed;

  ReleaseStatusState copyWith({
    UiFlowStatus? status,
    Object? error,
    bool clearError = false,
    ServerReleaseStatusSnapshot? snapshot,
    bool? updateNoticeDismissed,
  }) =>
      ReleaseStatusState(
        status: status ?? this.status,
        error: clearError ? null : error ?? this.error,
        snapshot: snapshot ?? this.snapshot,
        updateNoticeDismissed:
            updateNoticeDismissed ?? this.updateNoticeDismissed,
      );

  bool get shouldShowNotice {
    final value = snapshot;
    if (value == null || !value.needsAttention) return false;
    return value.status == ServerReleaseStatus.criticalReleaseWarning ||
        !updateNoticeDismissed;
  }

  @override
  bool get isIdle => status == UiFlowStatus.idle;
  @override
  bool get isLoading => status == UiFlowStatus.loading;
  @override
  bool get isSuccess => status == UiFlowStatus.success;
  @override
  bool get isFailure => status == UiFlowStatus.failure;
  @override
  bool get hasError => error != null;
}

@injectable
class ReleaseStatusCubit extends AppCubit<ReleaseStatusState> {
  ReleaseStatusCubit(this._service) : super(const ReleaseStatusState());

  final IServerReleaseStatusService _service;
  StreamSubscription<bool>? _authSubscription;

  void start() {
    _authSubscription ??= _service.authenticationChanges.listen((signedIn) {
      if (signedIn) {
        load();
      } else if (!isClosed) {
        emit(const ReleaseStatusState());
      }
    });
    if (_service.isAuthenticated) load();
  }

  Future<void> load() async {
    if (!_service.isAuthenticated || isClosed) return;
    await tryOperation(() async {
      final snapshot = await _service.inspect();
      return state.copyWith(
        status: UiFlowStatus.success,
        clearError: true,
        snapshot: snapshot,
        updateNoticeDismissed: false,
      );
    }, emitLoading: state.snapshot == null);
  }

  void dismissUpdateNotice() {
    if (state.snapshot?.status == ServerReleaseStatus.updateAvailable) {
      emit(state.copyWith(updateNoticeDismissed: true));
    }
  }

  @override
  Future<void> close() async {
    await _authSubscription?.cancel();
    return super.close();
  }
}
