import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/skills/i_skills_repository.dart';
import 'package:pocketcoder_flutter/domain/models/skill.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/infrastructure/core/api_endpoints.dart';

@LazySingleton(as: ISkillsRepository)
class SkillsRepository implements ISkillsRepository {
  final PocketBase _pb;

  SkillsRepository(this._pb);

  @override
  Future<List<Skill>> listSkills() async {
    return tryMethod(
      () async {
        final response = await _pb.send<dynamic>(
          ApiEndpoints.skillsList,
          method: 'POST',
          body: {},
        );
        final skills = (response as Map<String, dynamic>)['skills'] as List;
        return skills
            .map((s) => Skill.fromJson(s as Map<String, dynamic>))
            .toList();
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
        final scope = global
            ? {'scope': 'global'}
            : {'scope': 'projectDir', 'projectDir': projectDir};
        final response = await _pb.send<dynamic>(
          ApiEndpoints.skillsCreate,
          method: 'POST',
          body: {
            'name': name,
            'description': description,
            'content': content,
            'scope': scope,
          },
        );
        return Skill.fromJson(response as Map<String, dynamic>);
      },
      SkillsException.new,
      'createSkill',
    );
  }

  @override
  Future<Skill> updateSkill({
    required String path,
    required String name,
    required String description,
    required String content,
  }) async {
    return tryMethod(
      () async {
        final response = await _pb.send<dynamic>(
          ApiEndpoints.skillsUpdate,
          method: 'POST',
          body: {
            'path': path,
            'name': name,
            'description': description,
            'content': content,
          },
        );
        return Skill.fromJson(response as Map<String, dynamic>);
      },
      SkillsException.new,
      'updateSkill',
    );
  }

  @override
  Future<void> deleteSkill(String path) async {
    return tryMethod(
      () async {
        await _pb.send<dynamic>(
          ApiEndpoints.skillsDelete,
          method: 'POST',
          body: {'path': path},
        );
      },
      SkillsException.new,
      'deleteSkill',
    );
  }
}
