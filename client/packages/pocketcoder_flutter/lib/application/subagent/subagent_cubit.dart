import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../domain/subagent/i_subagent_repository.dart';
import 'subagent_state.dart';

@injectable
class SubagentCubit extends Cubit<SubagentState> {
  final ISubagentRepository _repository;
  StreamSubscription? _subscription;

  SubagentCubit(this._repository) : super(const SubagentState());

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  void watchChat(String chatId) {
    emit(state.copyWith(isLoading: true));
    _subscription?.cancel();
    _subscription = _repository.watchSubagents(chatId).listen(
          (subagents) =>
              emit(state.copyWith(subagents: subagents, isLoading: false)),
          onError: (e) =>
              emit(state.copyWith(error: e.toString(), isLoading: false)),
        );
  }

  Future<void> terminate(String id) async {
    try {
      await _repository.terminateSubagent(id);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
