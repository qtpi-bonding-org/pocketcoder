import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/skills/i_skills_repository.dart';
import 'package:pocketcoder_flutter/domain/models/skill.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/infrastructure/skills/skill_dao.dart';

@LazySingleton(as: ISkillsRepository)
class SkillsRepository implements ISkillsRepository {
  final SkillDao _dao;

  SkillsRepository(this._dao);

  @override
  Future<List<Skill>> listSkills() async {
    return tryMethod(
      () async {
        return _dao.getFullList(filter: 'active = true', sort: 'name');
      },
      SkillsException.new,
      'listSkills',
    );
  }

  @override
  Future<Skill> createSkill({
    required String name,
    required String description,
    required String content,
    required bool global,
    String? projectDir,
  }) async {
    return tryMethod(
      () async {
        return _dao.save(
          null,
          {
            'name': name,
            'description': description,
            'content': content,
            if (!global) 'metadata': {'projectDir': projectDir},
          },
        );
      },
      SkillsException.new,
      'createSkill',
    );
  }

  @override
  Future<Skill> updateSkill({
    required String id,
    required String name,
    required String description,
    required String content,
  }) async {
    return tryMethod(
      () async {
        return _dao.save(
          id,
          {
            'name': name,
            'description': description,
            'content': content,
          },
        );
      },
      SkillsException.new,
      'updateSkill',
    );
  }

  @override
  Future<void> deleteSkill(String id) async {
    return tryMethod(
      () async {
        await _dao.delete(id);
      },
      SkillsException.new,
      'deleteSkill',
    );
  }
}
