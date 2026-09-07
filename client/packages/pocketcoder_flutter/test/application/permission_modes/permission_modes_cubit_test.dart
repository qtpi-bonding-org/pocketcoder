import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/application/permission_modes/permission_modes_cubit.dart';
import 'package:pocketcoder_flutter/application/permission_modes/permission_modes_state.dart';
import 'package:pocketcoder_flutter/domain/models/permission_mode.dart';
import 'package:pocketcoder_flutter/domain/permission_modes/i_permission_mode_repository.dart';

class MockPermissionModeRepository extends Mock
    implements IPermissionModeRepository {}

class _FakePermissionMode extends Fake implements PermissionMode {}

void main() {
  late MockPermissionModeRepository repo;
  PermissionModesCubit? lastCubit;

  setUpAll(() {
    registerFallbackValue(_FakePermissionMode());
  });

  setUp(() {
    repo = MockPermissionModeRepository();
  });

  tearDown(() async {
    await lastCubit?.close();
  });

  PermissionModesCubit build() {
    lastCubit = PermissionModesCubit(repo);
    return lastCubit!;
  }

  final mode = PermissionMode(
    id: 'mode-1',
    name: 'read',
    baseSessionMode: PermissionModeBaseSessionMode.approve,
    isSystem: true,
  );

  test('watchModes emits loading then success with modes', () async {
    when(() => repo.watchModes()).thenAnswer((_) => Stream.value([mode]));
    final cubit = build();

    final states = <PermissionModesState>[];
    final sub = cubit.stream.listen(states.add);
    cubit.watchModes();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states.first.status, UiFlowStatus.loading);
    expect(states.last.status, UiFlowStatus.success);
    expect(states.last.modes, [mode]);
  });

  test('watchModes emits failure on repository error', () async {
    when(() => repo.watchModes())
        .thenAnswer((_) => Stream.error(Exception('boom')));
    final cubit = build();

    final states = <PermissionModesState>[];
    final sub = cubit.stream.listen(states.add);
    cubit.watchModes();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(states.last.status, UiFlowStatus.failure);
  });

  test('duplicateMode delegates to repository', () async {
    when(() => repo.duplicateMode(
          source: any(named: 'source'),
          newName: any(named: 'newName'),
        )).thenAnswer((_) async {});
    final cubit = build();

    await cubit.duplicateMode(source: mode, newName: 'my copy');

    verify(() => repo.duplicateMode(source: mode, newName: 'my copy'))
        .called(1);
  });

  test('deleteMode delegates to repository', () async {
    when(() => repo.deleteMode(any())).thenAnswer((_) async {});
    final cubit = build();

    await cubit.deleteMode('mode-1');

    verify(() => repo.deleteMode('mode-1')).called(1);
  });
}
