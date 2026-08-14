import 'dart:async';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/sandbox_agent/i_sandbox_agent_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_capture.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';
import 'sandbox_agent_state.dart';

@injectable
class SandboxAgentCubit extends AppCubit<SandboxAgentState> {
  final ISandboxAgentRepository _repository;
  StreamSubscription? _subscription;

  SandboxAgentCubit(this._repository) : super(const SandboxAgentState());

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  void watchChat(String chatId) {
    emit(state.copyWith(status: UiFlowStatus.loading));
    _subscription?.cancel();
    _subscription = _repository.watchSandboxAgents(chatId).listen(
      (sandboxAgents) => emit(state.copyWith(
        status: UiFlowStatus.success,
        error: null,
        sandboxAgents: sandboxAgents,
      )),
      onError: (e) {
        unawaited(pocketCoderDiagnosticCapture.capture(
          error: e,
          source: 'SandboxAgentCubit',
          operation: 'watchChat',
        ));
        emit(state.copyWith(error: e.toString(), status: UiFlowStatus.failure));
      },
    );
  }

  Future<void> terminate(String id) async {
    await tryOperation(() async {
      await _repository.terminateSandboxAgent(id);
      return state.copyWith(status: UiFlowStatus.success, error: null);
    });
  }
}
