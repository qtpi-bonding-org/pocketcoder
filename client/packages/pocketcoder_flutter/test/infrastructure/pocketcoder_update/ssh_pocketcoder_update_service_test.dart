import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_command_runner.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command_result.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_exception.dart';
import 'package:pocketcoder_flutter/domain/pocketcoder_update/pocketcoder_update_exception.dart';
import 'package:pocketcoder_flutter/domain/release/i_server_release_status_service.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/infrastructure/pocketcoder_update/ssh_pocketcoder_update_service.dart';

class _CommandRunner implements IRootSshCommandRunner {
  _CommandRunner({this.result, this.error});

  final RootSshCommandResult? result;
  final Object? error;
  String? instanceId;
  String? host;
  RootSshCommand? command;

  @override
  Future<RootSshCommandResult> run({
    required String instanceId,
    required String host,
    required RootSshCommand command,
  }) async {
    this.instanceId = instanceId;
    this.host = host;
    this.command = command;
    if (error != null) throw error!;
    return result!;
  }
}

class _ReleaseStatusService implements IServerReleaseStatusService {
  static final snapshot = ServerReleaseStatusSnapshot(
    status: ServerReleaseStatus.current,
    currentVersion: '1.0.0',
    currentDataVersion: 1,
    currentReleaseDigest: 'a' * 64,
    checkedAt: null,
  );

  @override
  Stream<bool> get authenticationChanges => const Stream.empty();

  @override
  bool get isAuthenticated => true;

  @override
  Future<ServerReleaseStatusSnapshot> inspect() async => snapshot;
}

SshPocketCoderUpdateService _service(IRootSshCommandRunner commandRunner) =>
    SshPocketCoderUpdateService(
      rootSshCommandRunner: commandRunner,
      pocketBase: PocketBase('https://example.com'),
      releaseStatusService: _ReleaseStatusService(),
    );

void main() {
  test('delegates release inspection', () async {
    expect(
      await _service(_CommandRunner()).inspect(),
      _ReleaseStatusService.snapshot,
    );
  });

  test('delegates the fixed PocketCoder update operation', () async {
    const commandResult = RootSshCommandResult(
      exitCode: 0,
      stdout: 'updated',
      stderr: '',
    );
    final runner = _CommandRunner(result: commandResult);

    final result = await _service(runner).updatePocketCoder(
      instanceId: 'instance-123',
    );

    expect(runner.instanceId, 'instance-123');
    expect(runner.host, 'example.com');
    expect(runner.command, RootSshCommand.updatePocketCoder);
    expect(result.exitCode, commandResult.exitCode);
    expect(result.stdout, commandResult.stdout);
    expect(result.stderr, commandResult.stderr);
  });

  test('maps SSH transport failures to the update exception', () async {
    await expectLater(
      _service(
        _CommandRunner(
          error: const RootSshException('SSH identity rejected'),
        ),
      ).updatePocketCoder(instanceId: 'instance'),
      throwsA(
        isA<PocketCoderUpdateException>().having(
          (error) => error.message,
          'message',
          contains('RootSshException'),
        ),
      ),
    );
  });
}
