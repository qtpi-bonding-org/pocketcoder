import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/skills/i_skills_repository.dart';
import 'package:pocketcoder_flutter/domain/models/poco_config.dart';
import 'package:pocketcoder_flutter/domain/agent_config/i_agent_config_repository.dart';
import 'package:pocketcoder_flutter/support/extensions/cubit_ui_flow_extension.dart';

import 'skills_state.dart';

@injectable
class SkillsCubit extends AppCubit<SkillsState> {
  final ISkillsRepository _repository;
  final IAgentConfigRepository _configRepository;

  SkillsCubit(this._repository, this._configRepository)
      : super(const SkillsState());

  Stream<List<PocoConfig>> watchConfigs() => _configRepository.watchConfigs();

  Future<void> loadSkills() async {
    await tryOperation(() async {
      final skills = await _repository.listSkills();
      return state.copyWith(
        status: UiFlowStatus.success,
        error: null,
        skills: skills,
      );
    }, emitLoading: true);
  }

  Future<void> createSkill({
    required String name,
    required String description,
    required String content,
    required bool global,
    String? projectDir,
  }) async {
    await tryOperation(() async {
      await _repository.createSkill(
        name: name,
        description: description,
        content: content,
        global: global,
        projectDir: projectDir,
      );
      final skills = await _repository.listSkills();
      return state.copyWith(
        status: UiFlowStatus.success,
        error: null,
        skills: skills,
      );
    });
  }

  Future<void> updateSkill({
    required String id,
    required String name,
    required String description,
    required String content,
  }) async {
    await tryOperation(() async {
      await _repository.updateSkill(
        id: id,
        name: name,
        description: description,
        content: content,
      );
      final skills = await _repository.listSkills();
      return state.copyWith(
        status: UiFlowStatus.success,
        error: null,
        skills: skills,
      );
    });
  }

  Future<void> deleteSkill(String id) async {
    await tryOperation(() async {
      await _repository.deleteSkill(id);
      final skills = await _repository.listSkills();
      return state.copyWith(
        status: UiFlowStatus.success,
        error: null,
        skills: skills,
      );
    });
  }
}
