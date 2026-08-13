import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_key_provider.dart';
import 'package:pocketcoder_flutter/domain/pocketcoder_update/i_pocketcoder_update_service.dart';
import 'package:pocketcoder_flutter/domain/pocketcoder_update/pocketcoder_update_exception.dart';
import 'package:pocketcoder_flutter/domain/pocketcoder_update/pocketcoder_update_result.dart';
import 'package:pocketcoder_flutter/domain/release/i_server_release_status_service.dart';
import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';

const _updateCommand =
    'if [ -x /opt/pocketcoder/current/bin/pocketcoder-release ]; '
    'then /opt/pocketcoder/current/bin/pocketcoder-release update; '
    'else echo "PocketCoder OS release manager was not found" >&2; exit 1; fi';

/// Public, non-interactive root-SSH implementation of PocketCoder updates.
///
/// It is separate from the sandbox terminal connection. The command is fixed
/// here rather than supplied by UI code, keeping the privileged surface small
/// and inspectable for self-hosters.
class SshPocketCoderUpdateService implements IPocketCoderUpdateService {
  const SshPocketCoderUpdateService({
    required IRootSshKeyProvider rootSshKeyProvider,
    required PocketBase pocketBase,
    required IServerReleaseStatusService releaseStatusService,
  })  : _rootSshKeyProvider = rootSshKeyProvider,
        _pocketBase = pocketBase,
        _releaseStatusService = releaseStatusService;

  static const _sshPort = 22;

  final IRootSshKeyProvider _rootSshKeyProvider;
  final PocketBase _pocketBase;
  final IServerReleaseStatusService _releaseStatusService;

  @override
  Future<ServerReleaseStatusSnapshot> inspect() =>
      _releaseStatusService.inspect();

  @override
  Future<PocketCoderUpdateResult> updatePocketCoder({
    required String instanceId,
  }) async {
    final privateKey = await _rootSshKeyProvider.readRootSshPrivateKey(
      instanceId: instanceId,
    );
    if (privateKey == null || privateKey.isEmpty) {
      throw PocketCoderUpdateException(
        'No stored root credentials for instance $instanceId -- '
        'this device may not be the one that deployed it.',
      );
    }

    final host = Uri.parse(_pocketBase.baseURL).host;
    if (host.isEmpty) {
      throw const PocketCoderUpdateException(
        'No known server host to connect to.',
      );
    }

    late final List<SSHKeyPair> keyPairs;
    try {
      keyPairs = SSHKeyPair.fromPem(privateKey);
    } catch (_) {
      throw const PocketCoderUpdateException(
        'Stored root SSH key could not be parsed.',
      );
    }
    if (keyPairs.isEmpty) {
      throw const PocketCoderUpdateException(
        'Stored root SSH key could not be parsed.',
      );
    }

    final socket = await SSHSocket.connect(host, _sshPort);
    final client = SSHClient(
      socket,
      username: 'root',
      identities: keyPairs,
    );

    try {
      await client.authenticated;
      final session = await client.execute(_updateCommand);
      final stdoutBytes = BytesBuilder();
      final stderrBytes = BytesBuilder();
      final stdoutDone = session.stdout.listen(stdoutBytes.add).asFuture();
      final stderrDone = session.stderr.listen(stderrBytes.add).asFuture();
      await session.done;
      await Future.wait([stdoutDone, stderrDone]);

      return PocketCoderUpdateResult(
        exitCode: session.exitCode ?? -1,
        stdout: utf8.decode(stdoutBytes.toBytes(), allowMalformed: true),
        stderr: utf8.decode(stderrBytes.toBytes(), allowMalformed: true),
      );
    } finally {
      client.close();
    }
  }
}
