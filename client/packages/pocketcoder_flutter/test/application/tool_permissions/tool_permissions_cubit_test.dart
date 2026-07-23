import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/tool_permissions/tool_permissions_cubit.dart';
import 'package:pocketcoder_flutter/domain/tool_permissions/i_tool_permission_repository.dart';

class MockToolPermissionRepository extends Mock
    implements IToolPermissionRepository {}

void main() {
  late MockToolPermissionRepository repo;
  ToolPermissionsCubit? lastCubit;

  ToolPermissionsCubit buildCubit() {
    final cubit = ToolPermissionsCubit(repo);
    lastCubit = cubit;
    return cubit;
  }

  setUp(() {
    repo = MockToolPermissionRepository();
  });

  tearDown(() async {
    if (lastCubit != null) {
      await lastCubit!.close();
      lastCubit = null;
    }
  });

  group('ToolPermissionsCubit.createRule', () {
    test('calls repository.createRule with the given fields', () async {
      when(() => repo.createRule(
            tool: any(named: 'tool'),
            action: any(named: 'action'),
          )).thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.createRule(tool: 'bash', action: 'allow');

      verify(() => repo.createRule(tool: 'bash', action: 'allow')).called(1);
    });

    test('emits error state on repository failure', () async {
      when(() => repo.createRule(
            tool: any(named: 'tool'),
            action: any(named: 'action'),
          )).thenThrow(Exception('boom'));

      final cubit = buildCubit();
      await cubit.createRule(tool: 'bash', action: 'allow');

      expect(cubit.state.hasError, isTrue);
    });
  });

  group('ToolPermissionsCubit.updateAction', () {
    test('calls repository.updateAction with the given fields', () async {
      when(() => repo.updateAction(any(), any())).thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.updateAction('rule-1', 'deny');

      verify(() => repo.updateAction('rule-1', 'deny')).called(1);
    });

    test('emits error state on repository failure', () async {
      when(() => repo.updateAction(any(), any())).thenThrow(Exception('boom'));

      final cubit = buildCubit();
      await cubit.updateAction('rule-1', 'deny');

      expect(cubit.state.hasError, isTrue);
    });
  });

  group('ToolPermissionsCubit.setActive', () {
    test('calls repository.setActive with the given fields', () async {
      when(() => repo.setActive(any(), any())).thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.setActive('rule-1', false);

      verify(() => repo.setActive('rule-1', false)).called(1);
    });

    test('emits error state on repository failure', () async {
      when(() => repo.setActive(any(), any())).thenThrow(Exception('boom'));

      final cubit = buildCubit();
      await cubit.setActive('rule-1', false);

      expect(cubit.state.hasError, isTrue);
    });
  });
}
