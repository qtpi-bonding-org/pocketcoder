import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../domain/ai_config/i_ai_config_repository.dart';
import 'ai_state.dart';
import '../../domain/ai/ai_models.dart';

@injectable
class AiCubit extends Cubit<AiState> {
  final IAiConfigRepository _repository;

  AiCubit(this._repository) : super(const AiState());

  Future<void> loadAll() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final agents = await _repository.getAgents();
      final prompts = await _repository.getPrompts();
      final models = await _repository.getModels();
      emit(state.copyWith(
        isLoading: false,
        agents: agents,
        prompts: prompts,
        models: models,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> saveAgent(AiAgent agent) async {
    try {
      await _repository.saveAgent(agent);
      await loadAll();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> deleteAgent(String id) async {
    try {
      await _repository.deleteAgent(id);
      await loadAll();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> savePrompt(AiPrompt prompt) async {
    try {
      await _repository.savePrompt(prompt);
      await loadAll();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> saveModel(AiModel model) async {
    try {
      await _repository.saveModel(model);
      await loadAll();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
