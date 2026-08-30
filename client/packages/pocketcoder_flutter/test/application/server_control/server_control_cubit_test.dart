import 'dart:async';

import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/server_control/server_control_cubit.dart';
import 'package:pocketcoder_flutter/application/server_control/server_control_state.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/domain/security/i_local_auth_gate.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_control_service.dart';
import 'package:pocketcoder_flutter/domain/server_control/server_control_exception.dart';
import 'package:pocketcoder_flutter/domain/server_control/server_control_result.dart';

const _digest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

class _FakeService implements IServerControlService {
  @override
  Future<String?> readPublicKey({required String instanceId}) =>
      throw UnimplementedError();

  String? privateKey;

  @override
  Future<String?> readPrivateKey({required String instanceId}) async =>
      privateKey;

  final calls = <String>[];
  final pending = <String, Completer<ServerControlResult>>{};
  ServerReleaseStatusSnapshot? release;
  Object? error;
  void Function()? onInspect;

  @override
  Future<ServerReleaseStatusSnapshot> inspectRelease() async {
    calls.add('inspectRelease');
    onInspect?.call();
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

class _FakeLocalAuthGate implements ILocalAuthGate {
  _FakeLocalAuthGate({this.approve = true});

  bool approve;
  final reasons = <String>[];

  @override
  Future<bool> authenticate({required String reason}) async {
    reasons.add(reason);
    return approve;
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
    final service = _FakeService()..release = _release();
    final cubit = ServerControlCubit(service, _FakeLocalAuthGate());

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
      'inspectRelease',
      'updatePocketCoder:server-1',
      'inspectRelease',
      'restartNixOs:server-1',
      'inspectRelease',
      'updateNixOs:server-1',
      'inspectRelease',
      'saveBackup:server-1',
    ]);
    await cubit.close();
  });

  test('emits failure when an operation throws', () async {
    final service = _FakeService();
    final cubit = ServerControlCubit(service, _FakeLocalAuthGate());
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
    final cubit = ServerControlCubit(service, _FakeLocalAuthGate());
    final future = cubit.inspectRelease();
    expect(cubit.state.status, UiFlowStatus.loading);
    await future;

    expect(cubit.state.status, UiFlowStatus.success);
    expect(cubit.state.release, service.release);
    await cubit.close();
  });

  test('reports release inspection failure', () async {
    final service = _FakeService()..error = StateError('unavailable');
    final cubit = ServerControlCubit(service, _FakeLocalAuthGate());
    await cubit.inspectRelease();

    expect(cubit.state.status, UiFlowStatus.failure);
    expect(cubit.state.error, isA<StateError>());
    await cubit.close();
  });

  test('revealPrivateKey fetches the key once local auth succeeds', () async {
    final service = _FakeService()..privateKey = 'PRIVATE-KEY-PEM';
    final gate = _FakeLocalAuthGate(approve: true);
    final cubit = ServerControlCubit(service, gate);

    await cubit.revealPrivateKey(instanceId: 'server-1', authReason: 'why');

    expect(cubit.state.privateKey, 'PRIVATE-KEY-PEM');
    expect(gate.reasons, ['why']);
    await cubit.close();
  });

  test('revealPrivateKey never fetches the key when local auth is denied',
      () async {
    final service = _FakeService()..privateKey = 'PRIVATE-KEY-PEM';
    final gate = _FakeLocalAuthGate(approve: false);
    final cubit = ServerControlCubit(service, gate);

    await cubit.revealPrivateKey(instanceId: 'server-1', authReason: 'why');

    expect(cubit.state.privateKey, isNull);
    await cubit.close();
  });

  test('confirmLocalAuth delegates to the gate', () async {
    final gate = _FakeLocalAuthGate(approve: true);
    final cubit = ServerControlCubit(_FakeService(), gate);

    expect(await cubit.confirmLocalAuth(reason: 'why'), isTrue);
    expect(gate.reasons, ['why']);
    await cubit.close();
  });

  test('a successful restart/update op refreshes release status', () async {
    final service = _FakeService()..release = _release();
    final cubit = ServerControlCubit(service, _FakeLocalAuthGate());
    final future = cubit.run(
      operation: ServerControlOperation.updatePocketCoder,
      instanceId: 'server-1',
    );
    service.pending['updatePocketCoder']!.complete(
      _result(RootSshCommand.updatePocketCoder),
    );
    await future;

    expect(cubit.state.release, service.release);
    expect(service.calls, contains('inspectRelease'));
    await cubit.close();
  });

  test('saveBackup does not refresh release status', () async {
    final service = _FakeService()..release = _release();
    final cubit = ServerControlCubit(service, _FakeLocalAuthGate());
    final future = cubit.run(
      operation: ServerControlOperation.saveBackup,
      instanceId: 'server-1',
    );
    service.pending['saveBackup']!.complete(_result(RootSshCommand.saveBackup));
    await future;

    expect(service.calls, isNot(contains('inspectRelease')));
    await cubit.close();
  });

  test('a failed operation does not refresh release status', () async {
    final service = _FakeService();
    final cubit = ServerControlCubit(service, _FakeLocalAuthGate());
    final future = cubit.run(
      operation: ServerControlOperation.updatePocketCoder,
      instanceId: 'server-1',
    );
    service.pending['updatePocketCoder']!.completeError(
      const ServerControlException('update failed'),
    );
    await future;

    expect(service.calls, isNot(contains('inspectRelease')));
    await cubit.close();
  });

  test(
      'a refresh that fails on the first attempt retries once and keeps '
      'the last-known release without surfacing an error', () async {
    final service = _FakeService()..release = _release();
    var inspectCalls = 0;
    service.onInspect = () {
      inspectCalls++;
      if (inspectCalls == 1) throw StateError('connection reset');
    };
    final cubit = ServerControlCubit(service, _FakeLocalAuthGate());
    final future = cubit.run(
      operation: ServerControlOperation.updatePocketCoder,
      instanceId: 'server-1',
    );
    service.pending['updatePocketCoder']!.complete(
      _result(RootSshCommand.updatePocketCoder),
    );
    await future;

    expect(inspectCalls, 2);
    expect(cubit.state.release, service.release);
    expect(cubit.state.status, UiFlowStatus.success,
        reason: 'the update itself succeeded; a refresh retry must not '
            'surface an error for it');
    await cubit.close();
  }, timeout: const Timeout(Duration(seconds: 10)));

  test(
      'a refresh that fails on both attempts keeps the last-known release '
      'without surfacing an error', () async {
    final service = _FakeService()
      ..release = _release()
      ..error = StateError('still unreachable');
    final cubit = ServerControlCubit(service, _FakeLocalAuthGate());
    final future = cubit.run(
      operation: ServerControlOperation.updatePocketCoder,
      instanceId: 'server-1',
    );
    service.pending['updatePocketCoder']!.complete(
      _result(RootSshCommand.updatePocketCoder),
    );
    await future;

    expect(cubit.state.release, isNull);
    expect(cubit.state.status, UiFlowStatus.success);
    await cubit.close();
  }, timeout: const Timeout(Duration(seconds: 10)));
}
