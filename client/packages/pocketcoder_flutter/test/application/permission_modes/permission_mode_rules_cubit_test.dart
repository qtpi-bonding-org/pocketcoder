import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/application/permission_modes/permission_mode_rules_cubit.dart';
import 'package:pocketcoder_flutter/application/permission_modes/permission_mode_rules_state.dart';
import 'package:pocketcoder_flutter/domain/models/permission_mode.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:pocketcoder_flutter/domain/permission_modes/i_permission_mode_repository.dart';

class MockPermissionModeRepository extends Mock
    implements IPermissionModeRepository {}

class _FakePermissionMode extends Fake implements PermissionMode {}

void main() {
  late MockPermissionModeRepository repo;
  PermissionModeRulesCubit? lastCubit;

  setUpAll(() {
    registerFallbackValue(_FakePermissionMode());
  });

  setUp(() {
    repo = MockPermissionModeRepository();
  });

  tearDown(() async {
    await lastCubit?.close();
  });

  PermissionModeRulesCubit build() {
    lastCubit = PermissionModeRulesCubit(repo);
    return lastCubit!;
  }

  final rule = ToolPermission(
    id: 'rule-1',
    tool: 'bash',
    pattern: 'ls *',
    action: ToolPermissionAction.allow,
    active: true,
    permissionMode: 'mode-1',
  );

  test('watchRules emits loading then success with rules', () async {
    when(() => repo.watchRules('mode-1')).thenAnswer((_) => Stream.value([rule]));
    final cubit = build();

    final states = <PermissionModeRulesState>[];
    final sub = cubit.stream.listen(states.add);
    cubit.watchRules('mode-1');
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states.first.status, UiFlowStatus.loading);
    expect(states.last.status, UiFlowStatus.success);
    expect(states.last.rules, [rule]);
  });

  test('watchRules emits failure on repository error', () async {
    when(() => repo.watchRules('mode-1'))
        .thenAnswer((_) => Stream.error(Exception('boom')));
    final cubit = build();

    final states = <PermissionModeRulesState>[];
    final sub = cubit.stream.listen(states.add);
    cubit.watchRules('mode-1');
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states.last.status, UiFlowStatus.failure);
  });

  test('createRule delegates to repository', () async {
    when(() => repo.createRule(
          modeId: any(named: 'modeId'),
          tool: any(named: 'tool'),
          action: any(named: 'action'),
        )).thenAnswer((_) async {});
    final cubit = build();

    await cubit.createRule(modeId: 'mode-1', tool: 'bash', action: 'allow');

    verify(() => repo.createRule(
          modeId: 'mode-1',
          tool: 'bash',
          action: 'allow',
        )).called(1);
  });

  test('updateAction delegates to repository', () async {
    when(() => repo.updateAction(any(), any())).thenAnswer((_) async {});
    final cubit = build();

    await cubit.updateAction('rule-1', 'deny');

    verify(() => repo.updateAction('rule-1', 'deny')).called(1);
  });

  test('setActive delegates to repository', () async {
    when(() => repo.setActive(any(), any())).thenAnswer((_) async {});
    final cubit = build();

    await cubit.setActive('rule-1', false);

    verify(() => repo.setActive('rule-1', false)).called(1);
  });
}
