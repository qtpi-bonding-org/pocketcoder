import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/infrastructure/skills/skills_repository.dart';

class MockPocketBase extends Mock implements PocketBase {}

void main() {
  late SkillsRepository repo;
  late MockPocketBase pb;

  setUp(() {
    pb = MockPocketBase();
    repo = SkillsRepository(pb);
  });

  group('SkillsRepository.listSkills', () {
    test('posts to skills/list and maps the response', () async {
      when(() => pb.send<dynamic>(
            '/api/pocketcoder/skills/list',
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {
            'skills': [
              {
                'name': 'my-skill',
                'description': 'd',
                'content': 'c',
                'path': '/global/my-skill',
                'global': true,
              }
            ]
          });

      final result = await repo.listSkills();

      expect(result, hasLength(1));
      expect(result.first.name, 'my-skill');
      expect(result.first.global, isTrue);
      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/skills/list',
            method: 'POST',
            body: {},
          )).called(1);
    });

    test('wraps failures in SkillsException', () async {
      when(() => pb.send<dynamic>(
            any(),
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenThrow(Exception('boom'));

      await expectLater(() => repo.listSkills(), throwsA(isA<SkillsException>()));
    });
  });

  group('SkillsRepository.createSkill', () {
    test('posts a global-scope request', () async {
      when(() => pb.send<dynamic>(
            '/api/pocketcoder/skills/create',
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {
            'name': 'my-skill',
            'description': 'd',
            'content': 'c',
            'path': '/global/my-skill',
            'global': true,
          });

      await repo.createSkill(
        name: 'my-skill',
        description: 'd',
        content: 'c',
        global: true,
      );

      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/skills/create',
            method: 'POST',
            body: {
              'name': 'my-skill',
              'description': 'd',
              'content': 'c',
              'scope': {'scope': 'global'},
            },
          )).called(1);
    });

    test('posts a projectDir-scope request', () async {
      when(() => pb.send<dynamic>(
            '/api/pocketcoder/skills/create',
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {
            'name': 'my-skill',
            'description': 'd',
            'content': 'c',
            'path': '/repo/.agents/skills/my-skill',
            'global': false,
          });

      await repo.createSkill(
        name: 'my-skill',
        description: 'd',
        content: 'c',
        global: false,
        projectDir: '/repo',
      );

      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/skills/create',
            method: 'POST',
            body: {
              'name': 'my-skill',
              'description': 'd',
              'content': 'c',
              'scope': {'scope': 'projectDir', 'projectDir': '/repo'},
            },
          )).called(1);
    });

    test('wraps failures in SkillsException', () async {
      when(() => pb.send<dynamic>(
            any(),
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenThrow(Exception('boom'));

      await expectLater(
        () => repo.createSkill(name: 'n', description: 'd', content: 'c', global: true),
        throwsA(isA<SkillsException>()),
      );
    });
  });

  group('SkillsRepository.updateSkill', () {
    test('posts path/name/description/content', () async {
      when(() => pb.send<dynamic>(
            '/api/pocketcoder/skills/update',
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {
            'name': 'renamed',
            'description': 'd2',
            'content': 'c2',
            'path': '/global/my-skill',
            'global': true,
          });

      await repo.updateSkill(
        path: '/global/my-skill',
        name: 'renamed',
        description: 'd2',
        content: 'c2',
      );

      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/skills/update',
            method: 'POST',
            body: {
              'path': '/global/my-skill',
              'name': 'renamed',
              'description': 'd2',
              'content': 'c2',
            },
          )).called(1);
    });
  });

  group('SkillsRepository.deleteSkill', () {
    test('posts the path', () async {
      when(() => pb.send<dynamic>(
            '/api/pocketcoder/skills/delete',
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {'deleted': true});

      await repo.deleteSkill('/global/my-skill');

      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/skills/delete',
            method: 'POST',
            body: {'path': '/global/my-skill'},
          )).called(1);
    });

    test('wraps failures in SkillsException', () async {
      when(() => pb.send<dynamic>(
            any(),
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenThrow(Exception('boom'));

      await expectLater(
        () => repo.deleteSkill('/global/my-skill'),
        throwsA(isA<SkillsException>()),
      );
    });
  });
}
