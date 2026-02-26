import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/domain/ai_config/i_ai_config_repository.dart';
import "package:flutter_aeroform/support/extensions/cubit_ui_flow_extension.dart";
import 'ai_config_state.dart';
import 'package:pocketcoder_flutter/domain/models/ai_agent.dart';
import 'package:pocketcoder_flutter/domain/models/ai_prompt.dart';
import 'package:pocketcoder_flutter/domain/models/ai_model.dart';

@injectable
class AiConfigCubit extends AppCubit<AiConfigState> {
  final IAiConfigRepository _repository;
  StreamSubscription? _agentsSub;
  StreamSubscription? _promptsSub;
  StreamSubscription? _modelsSub;

  AiConfigCubit(this._repository) : super(AiConfigState.initial());

  @override
  Future<void> close() {
    _agentsSub?.cancel();
    _promptsSub?.cancel();
    _modelsSub?.cancel();
    return super.close();
  }

  void watchAll() {
    emit(state.copyWith(status: UiFlowStatus.loading));

    _agentsSub?.cancel();
    _agentsSub = _repository.watchAgents().listen(
          (agents) => emit(
              state.copyWith(agents: agents, status: UiFlowStatus.success)),
          onError: (e) =>
              emit(state.copyWith(error: e, status: UiFlowStatus.failure)),
        );

    _promptsSub?.cancel();
    _promptsSub = _repository.watchPrompts().listen(
          (prompts) => emit(
              state.copyWith(prompts: prompts, status: UiFlowStatus.success)),
          onError: (e) =>
              emit(state.copyWith(error: e, status: UiFlowStatus.failure)),
        );

    _modelsSub?.cancel();
    _modelsSub = _repository.watchModels().listen(
          (models) => emit(
              state.copyWith(models: models, status: UiFlowStatus.success)),
          onError: (e) =>
              emit(state.copyWith(error: e, status: UiFlowStatus.failure)),
        );
  }

  Future<void> saveAgent(AiAgent agent) async {
    return tryOperation(() async {
      await _repository.saveAgent(agent);
      return createSuccessState();
    });
  }

  Future<void> deleteAgent(String id) async {
    return tryOperation(() async {
      await _repository.deleteAgent(id);
      return createSuccessState();
    });
  }

  Future<void> savePrompt(AiPrompt prompt) async {
    return tryOperation(() async {
      await _repository.savePrompt(prompt);
      return createSuccessState();
    });
  }

  Future<void> saveModel(AiModel model) async {
    return tryOperation(() async {
      await _repository.saveModel(model);
      return createSuccessState();
    });
  }
}
