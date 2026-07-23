import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import "package:pocketcoder_flutter/infrastructure/core/logger.dart";
import 'package:pocketcoder_flutter/domain/skills/i_skills_repository.dart';

import 'skills_state.dart';

@injectable
class SkillsCubit extends Cubit<SkillsState> {
  final ISkillsRepository _repository;

  SkillsCubit(this._repository) : super(const SkillsState.initial());

  Future<void> loadSkills() async {
    emit(const SkillsState.loading());
    try {
      final skills = await _repository.listSkills();
      emit(SkillsState.loaded(skills));
    } catch (e) {
      logError('Skills: Failed to load skills', e);
      emit(SkillsState.error(e.toString()));
    }
  }

  Future<void> createSkill({
    required String name,
    required String description,
    required String content,
    required bool global,
    String? projectDir,
  }) async {
    try {
      await _repository.createSkill(
        name: name,
        description: description,
        content: content,
        global: global,
        projectDir: projectDir,
      );
      await loadSkills();
    } catch (e) {
      logError('Skills: Failed to create skill', e);
      emit(SkillsState.error(e.toString()));
    }
  }

  Future<void> updateSkill({
    required String path,
    required String name,
    required String description,
    required String content,
  }) async {
    try {
      await _repository.updateSkill(
        path: path,
        name: name,
        description: description,
        content: content,
      );
      await loadSkills();
    } catch (e) {
      logError('Skills: Failed to update skill', e);
      emit(SkillsState.error(e.toString()));
    }
  }

  Future<void> deleteSkill(String path) async {
    try {
      await _repository.deleteSkill(path);
      await loadSkills();
    } catch (e) {
      logError('Skills: Failed to delete skill', e);
      emit(SkillsState.error(e.toString()));
    }
  }
}