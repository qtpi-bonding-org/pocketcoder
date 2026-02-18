import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../domain/hitl/i_hitl_repository.dart';
import 'permission_state.dart';

@injectable
class PermissionCubit extends Cubit<PermissionState> {
  final IHitlRepository _repository;
  StreamSubscription? _subscription;

  PermissionCubit(this._repository) : super(const PermissionState.initial());

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  void watchChat(String chatId) {
    emit(const PermissionState.loading());
    _subscription?.cancel();
    _subscription = _repository.watchPending(chatId).listen(
          (requests) => emit(PermissionState.loaded(requests)),
          onError: (e) => emit(PermissionState.error(e.toString())),
        );
  }

  Future<void> authorize(String requestId) async {
    try {
      await _repository.authorize(requestId);
    } catch (e) {
      // Errors will be handled by the stream update ideally,
      // but we could emit an error state here if needed.
    }
  }

  Future<void> deny(String requestId) async {
    try {
      await _repository.deny(requestId);
    } catch (e) {
      // Handle error
    }
  }
}
