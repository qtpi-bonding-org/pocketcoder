import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/skills/skills_cubit.dart';
import 'package:pocketcoder_flutter/application/skills/skills_state.dart';
import 'package:pocketcoder_flutter/domain/models/skill.dart';
import 'package:pocketcoder_flutter/domain/skills/i_skills_repository.dart';
import 'package:pocketcoder_flutter/domain/agent_config/i_agent_config_repository.dart';

class MockSkillsRepository extends Mock implements ISkillsRepository {}
class MockAgentConfigRepository extends Mock implements IAgentConfigRepository {}

const _skill = Skill(
  name: 'my-skill',
  description: 'd',
  content: 'c',
  path: '/global/my-skill',
  global: true,
);

void main() {
  late MockSkillsRepository repo;
  late MockAgentConfigRepository configRepo;
  SkillsCubit? lastCubit;

  SkillsCubit buildCubit() {
    final cubit = SkillsCubit(repo, configRepo);
    lastCubit = cubit;
    return cubit;
  }

  setUp(() {
    repo = MockSkillsRepository();
    configRepo = MockAgentConfigRepository();
  });

  tearDown(() async {
    if (lastCubit != null) {
      await lastCubit!.close();
      lastCubit = null;
    }
  });

  group('SkillsCubit.loadSkills', () {
    test('emits loading then loaded on success', () async {
      when(() => repo.listSkills()).thenAnswer((_) async => [_skill]);

      final cubit = buildCubit();
      final states = <SkillsState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.loadSkills();
      // Cubit.stream delivers via a broadcast StreamController, which
      // schedules listener notification as its own microtask rather than
      // synchronously with emit() — flush the queue once more so the
      // `loaded` notification (scheduled during loadSkills()'s last emit)
      // has actually reached this subscription before we assert on it.
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(states, [
        const SkillsState.loading(),
        const SkillsState.loaded([_skill]),
      ]);
    });

    test('emits error on repository failure', () async {
      when(() => repo.listSkills()).thenThrow(Exception('boom'));

      final cubit = buildCubit();
      await cubit.loadSkills();

      expect(cubit.state.hasError, isTrue);
    });
  });

  group('SkillsCubit.createSkill', () {
    test('calls repository.createSkill then reloads', () async {
      when(() => repo.createSkill(
            name: any(named: 'name'),
            description: any(named: 'description'),
            content: any(named: 'content'),
            global: any(named: 'global'),
            projectDir: any(named: 'projectDir'),
          )).thenAnswer((_) async => _skill);
      when(() => repo.listSkills()).thenAnswer((_) async => [_skill]);

      final cubit = buildCubit();
      await cubit.createSkill(
        name: 'my-skill',
        description: 'd',
        content: 'c',
        global: true,
      );

      verify(() => repo.createSkill(
            name: 'my-skill',
            description: 'd',
            content: 'c',
            global: true,
            projectDir: null,
          )).called(1);
      verify(() => repo.listSkills()).called(1);
    });

    test('emits error on repository failure without reloading', () async {
      when(() => repo.createSkill(
            name: any(named: 'name'),
            description: any(named: 'description'),
            content: any(named: 'content'),
            global: any(named: 'global'),
            projectDir: any(named: 'projectDir'),
          )).thenThrow(Exception('boom'));

      final cubit = buildCubit();
      await cubit.createSkill(name: 'n', description: 'd', content: 'c', global: true);

      expect(cubit.state.hasError, isTrue);
      verifyNever(() => repo.listSkills());
    });
  });

  group('SkillsCubit.updateSkill', () {
    test('calls repository.updateSkill then reloads', () async {
      when(() => repo.updateSkill(
            path: any(named: 'path'),
            name: any(named: 'name'),
            description: any(named: 'description'),
            content: any(named: 'content'),
          )).thenAnswer((_) async => _skill);
      when(() => repo.listSkills()).thenAnswer((_) async => [_skill]);

      final cubit = buildCubit();
      await cubit.updateSkill(
        path: '/global/my-skill',
        name: 'renamed',
        description: 'd2',
        content: 'c2',
      );

      verify(() => repo.updateSkill(
            path: '/global/my-skill',
            name: 'renamed',
            description: 'd2',
            content: 'c2',
          )).called(1);
      verify(() => repo.listSkills()).called(1);
    });
  });

  group('SkillsCubit.deleteSkill', () {
    test('calls repository.deleteSkill then reloads', () async {
      when(() => repo.deleteSkill(any())).thenAnswer((_) async {});
      when(() => repo.listSkills()).thenAnswer((_) async => []);

      final cubit = buildCubit();
      await cubit.deleteSkill('/global/my-skill');

      verify(() => repo.deleteSkill('/global/my-skill')).called(1);
      verify(() => repo.listSkills()).called(1);
    });

    test('emits error on repository failure without reloading', () async {
      when(() => repo.deleteSkill(any())).thenThrow(Exception('boom'));

      final cubit = buildCubit();
      await cubit.deleteSkill('/global/my-skill');

      expect(cubit.state.hasError, isTrue);
      verifyNever(() => repo.listSkills());
    });
  });
}