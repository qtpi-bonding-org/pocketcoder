import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../domain/system/i_health_repository.dart';
import 'health_state.dart';

@injectable
class HealthCubit extends Cubit<HealthState> {
  final IHealthRepository _repository;
  StreamSubscription? _subscription;

  HealthCubit(this._repository) : super(const HealthState());

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  void initialize() {
    emit(state.copyWith(isLoading: true));
    _subscription?.cancel();
    _subscription = _repository.watchHealth().listen(
          (checks) => emit(state.copyWith(checks: checks, isLoading: false)),
          onError: (e) =>
              emit(state.copyWith(error: e.toString(), isLoading: false)),
        );
  }

  Future<void> refresh() async {
    try {
      await _repository.refreshHealth();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
