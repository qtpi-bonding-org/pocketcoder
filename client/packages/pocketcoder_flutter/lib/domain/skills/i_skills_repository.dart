import 'package:pocketcoder_flutter/domain/models/skill.dart';

abstract class ISkillsRepository {
  Future<List<Skill>> listSkills();
  Future<Skill> createSkill({
    required String name,
    required String description,
    required String content,
    required bool global,
    String? projectDir,
  });
  Future<Skill> updateSkill({
    required String path,
    required String name,
    required String description,
    required String content,
  });
  Future<void> deleteSkill(String path);
}
