import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/system/i_health_repository.dart';
import '../../support/extensions/cubit_ui_flow_extension.dart';
import 'health_state.dart';

@injectable
class HealthCubit extends AppCubit<HealthState> {
  final IHealthRepository _repository;
  StreamSubscription? _subscription;

  HealthCubit(this._repository) : super(const HealthState());

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  void watchHealth() {
    emit(state.copyWith(status: UiFlowStatus.loading));
    _subscription?.cancel();
    _subscription = _repository.watchHealth().listen(
          (checks) => emit(
              state.copyWith(checks: checks, status: UiFlowStatus.success)),
          onError: (e) =>
              emit(state.copyWith(error: e, status: UiFlowStatus.failure)),
        );
  }

  Future<void> refresh() async {
    return tryOperation(() async {
      await _repository.refreshHealth();
      return state;
    });
  }
}
