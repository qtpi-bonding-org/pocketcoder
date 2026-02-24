import 'package:injectable/injectable.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import '../../domain/ai_config/i_ai_config_repository.dart';
import '../../support/extensions/cubit_ui_flow_extension.dart';
import 'ai_config_state.dart';
import '../../domain/ai/ai_models.dart';

@injectable
class AiConfigCubit extends AppCubit<AiConfigState> {
  final IAiConfigRepository _repository;

  AiConfigCubit(this._repository) : super(AiConfigState.initial());

  Future<void> loadAll() async {
    return tryOperation(() async {
      final agents = await _repository.getAgents();
      final prompts = await _repository.getPrompts();
      final models = await _repository.getModels();
      return state.copyWith(
        status: UiFlowStatus.success,
        agents: agents,
        prompts: prompts,
        models: models,
        error: null,
      );
    });
  }

  Future<void> saveAgent(AiAgent agent) async {
    return tryOperation(() async {
      await _repository.saveAgent(agent);
      await loadAll();
      return createSuccessState();
    });
  }

  Future<void> deleteAgent(String id) async {
    return tryOperation(() async {
      await _repository.deleteAgent(id);
      await loadAll();
      return createSuccessState();
    });
  }

  Future<void> savePrompt(AiPrompt prompt) async {
    return tryOperation(() async {
      await _repository.savePrompt(prompt);
      await loadAll();
      return createSuccessState();
    });
  }

  Future<void> saveModel(AiModel model) async {
    return tryOperation(() async {
      await _repository.saveModel(model);
      await loadAll();
      return createSuccessState();
    });
  }
}
