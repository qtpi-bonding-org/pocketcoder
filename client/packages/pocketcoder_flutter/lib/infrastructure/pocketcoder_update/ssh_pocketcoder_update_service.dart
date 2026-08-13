import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_command_runner.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';
import 'package:pocketcoder_flutter/domain/pocketcoder_update/i_pocketcoder_update_service.dart';
import 'package:pocketcoder_flutter/domain/pocketcoder_update/pocketcoder_update_exception.dart';
import 'package:pocketcoder_flutter/domain/pocketcoder_update/pocketcoder_update_result.dart';
import 'package:pocketcoder_flutter/domain/release/i_server_release_status_service.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';

/// Public, non-interactive root-SSH implementation of PocketCoder updates.
///
/// It is separate from the sandbox terminal connection. The command is fixed
/// here rather than supplied by UI code, keeping the privileged surface small
/// and inspectable for self-hosters.
class SshPocketCoderUpdateService implements IPocketCoderUpdateService {
  const SshPocketCoderUpdateService({
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
  Future<ServerReleaseStatusSnapshot> inspect() => tryMethod(
        _releaseStatusService.inspect,
        PocketCoderUpdateException.new,
        'inspectPocketCoderUpdate',
      );

  @override
  Future<PocketCoderUpdateResult> updatePocketCoder({
    required String instanceId,
  }) =>
      tryMethod(
        () async {
          final host = Uri.parse(_pocketBase.baseURL).host;
          final result = await _rootSshCommandRunner.run(
            instanceId: instanceId,
            host: host,
            command: RootSshCommand.updatePocketCoder,
          );
          return PocketCoderUpdateResult(
            exitCode: result.exitCode,
            stdout: result.stdout,
            stderr: result.stderr,
          );
        },
        PocketCoderUpdateException.new,
        'updatePocketCoder',
      );
}
