import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/models/skill.dart';
import 'package:pocketcoder_flutter/infrastructure/skills/skill_dao.dart';
import 'package:pocketcoder_flutter/infrastructure/skills/skills_repository.dart';

class MockSkillDao extends Mock implements SkillDao {}

const skill = Skill(
  id: 'skill1',
  name: 'review',
  description: 'Review changes',
  content: 'Review the diff.',
);

void main() {
  late MockSkillDao dao;
  late SkillsRepository repository;

  setUp(() {
    dao = MockSkillDao();
    repository = SkillsRepository(dao);
  });

  test('lists active skills through the collection DAO', () async {
    when(() => dao.getFullList(filter: 'active = true', sort: 'name'))
        .thenAnswer((_) async => [skill]);

    expect(await repository.listSkills(), [skill]);
  });

  test('creates a project-scoped collection record', () async {
    when(() => dao.save(any(), any())).thenAnswer((_) async => skill);

    await repository.createSkill(
      name: 'review',
      description: 'Review changes',
      content: 'Review the diff.',
      global: false,
      projectDir: '/workspace/project',
    );

    verify(() => dao.save(null, {
          'name': 'review',
          'description': 'Review changes',
          'content': 'Review the diff.',
          'metadata': {'projectDir': '/workspace/project'},
        })).called(1);
  });

  test('updates and deletes by PocketBase record id', () async {
    when(() => dao.save(any(), any())).thenAnswer((_) async => skill);
    when(() => dao.delete(any())).thenAnswer((_) async {});

    await repository.updateSkill(
      id: 'skill1',
      name: 'review',
      description: 'Review changes',
      content: 'Review the diff.',
    );
    await repository.deleteSkill('skill1');

    verify(() => dao.save('skill1', any())).called(1);
    verify(() => dao.delete('skill1')).called(1);
  });
}
