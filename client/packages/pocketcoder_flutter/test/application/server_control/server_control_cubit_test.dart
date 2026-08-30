import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/server_control/server_control_cubit.dart';
import 'package:pocketcoder_flutter/application/server_control/server_control_state.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_control_service.dart';
import 'package:pocketcoder_flutter/domain/server_control/server_control_exception.dart';
import 'package:pocketcoder_flutter/domain/server_control/server_control_result.dart';

const _digest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

class _FakeService implements IServerControlService {
  @override
  Future<String?> readPublicKey({required String instanceId}) =>
      throw UnimplementedError();

  final calls = <String>[];
  final pending = <String, Completer<ServerControlResult>>{};
  ServerReleaseStatusSnapshot? release;
  Object? error;

  @override
  Future<ServerReleaseStatusSnapshot> inspectRelease() async {
    calls.add('inspectRelease');
    if (error case final error?) throw error;
    return release!;
  }

  @override
  Future<ServerControlResult> restartPocketCoder(
          {required String instanceId}) =>
      _run('restartPocketCoder', RootSshCommand.restartPocketCoder, instanceId);

  @override
  Future<ServerControlResult> updatePocketCoder({required String instanceId}) =>
      _run('updatePocketCoder', RootSshCommand.updatePocketCoder, instanceId);

  @override
  Future<ServerControlResult> restartNixOs({required String instanceId}) =>
      _run('restartNixOs', RootSshCommand.restartNixOs, instanceId);

  @override
  Future<ServerControlResult> updateNixOs({required String instanceId}) =>
      _run('updateNixOs', RootSshCommand.updateNixOs, instanceId);

  @override
  Future<ServerControlResult> saveBackup({required String instanceId}) =>
      _run('saveBackup', RootSshCommand.saveBackup, instanceId);

  Future<ServerControlResult> _run(
    String name,
    RootSshCommand command,
    String instanceId,
  ) {
    calls.add('$name:$instanceId');
    final completer = Completer<ServerControlResult>();
    pending[name] = completer;
    return completer.future;
  }
}

ServerReleaseStatusSnapshot _release() => ServerReleaseStatusSnapshot(
      status: ServerReleaseStatus.current,
      currentVersion: '1.2.3',
      currentDataVersion: 1,
      currentReleaseDigest: _digest,
      checkedAt: DateTime.utc(2026, 8, 14),
    );

ServerControlResult _result(RootSshCommand command) => ServerControlResult(
      command: command,
      exitCode: 0,
      stdout: 'ok',
      stderr: '',
    );

void main() {
  test('delegates all five operations with the instance id', () async {
    final service = _FakeService();
    final cubit = ServerControlCubit(service);

    for (final operation in ServerControlOperation.values) {
      final future = cubit.run(operation: operation, instanceId: 'server-1');
      expect(cubit.state.status, UiFlowStatus.loading);
      final name = operation.name;
      service.pending[name]!.complete(
        _result(ServerControlCubit.commandFor(operation)),
      );
      await future;
      expect(cubit.state.status, UiFlowStatus.success);
      expect(cubit.state.operation, operation);
      expect(cubit.state.result?.command,
          ServerControlCubit.commandFor(operation));
    }

    expect(service.calls, [
      'restartPocketCoder:server-1',
      'updatePocketCoder:server-1',
      'restartNixOs:server-1',
      'updateNixOs:server-1',
      'saveBackup:server-1',
    ]);
    await cubit.close();
  });

  test('emits failure when an operation throws', () async {
    final service = _FakeService();
    final cubit = ServerControlCubit(service);
    final future = cubit.run(
      operation: ServerControlOperation.saveBackup,
      instanceId: 'server-1',
    );
    service.pending['saveBackup']!.completeError(
      const ServerControlException('backup failed'),
    );
    await future;

    expect(cubit.state.status, UiFlowStatus.failure);
    expect(cubit.state.error, isA<ServerControlException>());
    await cubit.close();
  });

  test('inspects release with loading and success states', () async {
    final service = _FakeService()..release = _release();
    final cubit = ServerControlCubit(service);
    final future = cubit.inspectRelease();
    expect(cubit.state.status, UiFlowStatus.loading);
    await future;

    expect(cubit.state.status, UiFlowStatus.success);
    expect(cubit.state.release, service.release);
    await cubit.close();
  });

  test('reports release inspection failure', () async {
    final service = _FakeService()..error = StateError('unavailable');
    final cubit = ServerControlCubit(service);
    await cubit.inspectRelease();

    expect(cubit.state.status, UiFlowStatus.failure);
    expect(cubit.state.error, isA<StateError>());
    await cubit.close();
  });
}
