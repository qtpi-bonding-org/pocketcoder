import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_command_runner.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';
import 'package:pocketcoder_flutter/domain/release/i_server_release_status_service.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_control_service.dart';
import 'package:pocketcoder_flutter/domain/server_control/server_control_exception.dart';
import 'package:pocketcoder_flutter/domain/server_control/server_control_result.dart';

final class SshServerControlService implements IServerControlService {
  const SshServerControlService({
    required IRootSshCommandRunner rootSshCommandRunner,
    required PocketBase pocketBase,
    required IServerReleaseStatusService releaseStatusService,
  })  : _rootSshCommandRunner = rootSshCommandRunner,
        _pocketBase = pocketBase,
        _releaseStatusService = releaseStatusService;

  final IRootSshCommandRunner _rootSshCommandRunner;
  final PocketBase _pocketBase;
  final IServerReleaseStatusService _releaseStatusService;

  @override
  Future<ServerReleaseStatusSnapshot> inspectRelease() => tryMethod(
        _releaseStatusService.inspect,
        ServerControlException.new,
        'inspectRelease',
      );

  @override
  Future<ServerControlResult> restartPocketCoder({
    required String instanceId,
  }) =>
      _run(instanceId, RootSshCommand.restartPocketCoder);

  @override
  Future<ServerControlResult> updatePocketCoder({
    required String instanceId,
  }) =>
      _run(instanceId, RootSshCommand.updatePocketCoder);

  @override
  Future<ServerControlResult> restartNixOs({
    required String instanceId,
  }) =>
      _run(instanceId, RootSshCommand.restartNixOs);

  @override
  Future<ServerControlResult> updateNixOs({
    required String instanceId,
  }) =>
      _run(instanceId, RootSshCommand.updateNixOs);

  @override
  Future<ServerControlResult> saveBackup({
    required String instanceId,
  }) =>
      _run(instanceId, RootSshCommand.saveBackup);

  Future<ServerControlResult> _run(
    String instanceId,
    RootSshCommand command,
  ) =>
      tryMethod(
        () async {
          final host = Uri.parse(_pocketBase.baseURL).host;
          final result = await _rootSshCommandRunner.run(
            instanceId: instanceId,
            host: host,
            command: command,
          );
          return ServerControlResult(
            command: command,
            exitCode: result.exitCode,
            stdout: result.stdout,
            stderr: result.stderr,
          );
        },
        ServerControlException.new,
        command.name,
      );
}
