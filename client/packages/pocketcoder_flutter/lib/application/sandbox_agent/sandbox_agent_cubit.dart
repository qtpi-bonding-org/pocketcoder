import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/sandbox_agent/i_sandbox_agent_repository.dart';
import 'sandbox_agent_state.dart';

@injectable
class SandboxAgentCubit extends Cubit<SandboxAgentState> {
  final ISandboxAgentRepository _repository;
  StreamSubscription? _subscription;

  SandboxAgentCubit(this._repository) : super(const SandboxAgentState());

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  void watchChat(String chatId) {
    emit(state.copyWith(isLoading: true));
    _subscription?.cancel();
    _subscription = _repository.watchSandboxAgents(chatId).listen(
          (sandboxAgents) =>
              emit(state.copyWith(sandboxAgents: sandboxAgents, isLoading: false)),
          onError: (e) =>
              emit(state.copyWith(error: e.toString(), isLoading: false)),
        );
  }

  Future<void> terminate(String id) async {
    try {
      await _repository.terminateSandboxAgent(id);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
