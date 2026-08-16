import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_command_runner.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command_result.dart';
import 'package:pocketcoder_flutter/domain/release/i_server_release_status_service.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/domain/server_control/server_control_exception.dart';
import 'package:pocketcoder_flutter/infrastructure/server_control/ssh_server_control_service.dart';

const _digest =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

class _FakeRunner implements IRootSshCommandRunner {
  final calls = <({String instanceId, String host, RootSshCommand command})>[];
  Object? error;

  @override
  Future<RootSshCommandResult> run({
    required String instanceId,
    required String host,
    required RootSshCommand command,
    Uint8List? stdin,
  }) async {
    calls.add((instanceId: instanceId, host: host, command: command));
    if (error case final error?) throw error;
    return const RootSshCommandResult(
      exitCode: 7,
      stdout: 'partial output',
      stderr: 'failure output',
    );
  }
}

class _FakeReleaseService implements IServerReleaseStatusService {
  _FakeReleaseService(this.snapshot);

  final ServerReleaseStatusSnapshot snapshot;
  Object? error;
  int inspections = 0;

  @override
  bool get isAuthenticated => true;

  @override
  Stream<bool> get authenticationChanges => const Stream.empty();

  @override
  Future<ServerReleaseStatusSnapshot> inspect() async {
    inspections += 1;
    if (error case final error?) throw error;
    return snapshot;
  }
}

ServerReleaseStatusSnapshot _release() => ServerReleaseStatusSnapshot(
  status: ServerReleaseStatus.updateAvailable,
  currentVersion: '1.0.0',
  currentDataVersion: 1,
  currentReleaseDigest: _digest,
  checkedAt: DateTime.utc(2026, 8, 14),
);

void main() {
  test(
    'delegates every typed command and extracts the PocketBase host',
    () async {
      final runner = _FakeRunner();
      final service = SshServerControlService(
        rootSshCommandRunner: runner,
        pocketBase: PocketBase('https://pb.example.test:8090'),
        releaseStatusService: _FakeReleaseService(_release()),
      );

      for (final operation in <Future<dynamic> Function()>[
        () => service.restartPocketCoder(instanceId: 'instance-1'),
        () => service.updatePocketCoder(instanceId: 'instance-1'),
        () => service.restartNixOs(instanceId: 'instance-1'),
        () => service.updateNixOs(instanceId: 'instance-1'),
        () => service.saveBackup(instanceId: 'instance-1'),
      ]) {
        final result = await operation();
        expect(result.exitCode, 7);
        expect(result.stdout, 'partial output');
        expect(result.stderr, 'failure output');
      }

      expect(
        runner.calls.map((call) => call.host),
        everyElement('pb.example.test'),
      );
      expect(runner.calls.map((call) => call.command), [
        RootSshCommand.restartPocketCoder,
        RootSshCommand.updatePocketCoder,
        RootSshCommand.restartNixOs,
        RootSshCommand.updateNixOs,
        RootSshCommand.saveBackup,
      ]);
    },
  );

  test('delegates release inspection', () async {
    final release = _FakeReleaseService(_release());
    final service = SshServerControlService(
      rootSshCommandRunner: _FakeRunner(),
      pocketBase: PocketBase('https://pb.example.test'),
      releaseStatusService: release,
    );

    expect(await service.inspectRelease(), release.snapshot);
    expect(release.inspections, 1);
  });

  test('wraps runner failures with operation context', () async {
    final runner = _FakeRunner()..error = StateError('private detail');
    final service = SshServerControlService(
      rootSshCommandRunner: runner,
      pocketBase: PocketBase('https://pb.example.test'),
      releaseStatusService: _FakeReleaseService(_release()),
    );

    await expectLater(
      service.saveBackup(instanceId: 'instance-1'),
      throwsA(
        isA<ServerControlException>().having(
          (error) => error.message,
          'message',
          contains('saveBackup'),
        ),
      ),
    );
  });

  test('wraps release inspection failures', () async {
    final release = _FakeReleaseService(_release())
      ..error = StateError('private detail');
    final service = SshServerControlService(
      rootSshCommandRunner: _FakeRunner(),
      pocketBase: PocketBase('https://pb.example.test'),
      releaseStatusService: release,
    );

    await expectLater(
      service.inspectRelease(),
      throwsA(
        isA<ServerControlException>().having(
          (error) => error.message,
          'message',
          contains('inspectRelease'),
        ),
      ),
    );
  });
}
