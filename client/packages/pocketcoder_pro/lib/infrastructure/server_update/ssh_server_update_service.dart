import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';
import 'package:pocketbase/pocketbase.dart';

import 'package:pocketcoder_pro/domain/server_update/i_server_update_service.dart';
import 'package:pocketcoder_pro/domain/server_update/server_update_exception.dart';
import 'package:pocketcoder_pro/domain/server_update/server_update_result.dart';

/// Runs the packaged, verified release updater. The fallback migrates servers
/// installed before release artifacts existed by updating their old git clone
/// once, then handing control to the same packaged updater.
const _kUpdateCommand =
    'if [ -x /opt/pocketcoder/current/deploy/scripts/update-release.sh ]; '
    'then /opt/pocketcoder/current/deploy/scripts/update-release.sh; '
    'elif [ -d /opt/pocketcoder/.git ]; then cd /opt/pocketcoder && '
    'git pull --ff-only && deploy/scripts/update-release.sh; '
    'else echo "PocketCoder updater was not found" >&2; exit 1; fi';

const _kSshPort = 22;

// Registered manually in app.dart's initializeAeroformDI() -- this package
// has no injectable codegen of its own (only invokes flutter_aeroform's
// already-generated module), so its own classes are wired by hand there.
class SshServerUpdateService implements IServerUpdateService {
  final ISecureStorage _secureStorage;
  final PocketBase _pocketBase;

  SshServerUpdateService(this._secureStorage, this._pocketBase);

  @override
  Future<ServerUpdateResult> updateServer({required String instanceId}) async {
    final credentials = await _secureStorage.getInstanceCredentials(instanceId);
    if (credentials == null) {
      throw ServerUpdateException(
        'No stored root credentials for instance $instanceId -- '
        'this device may not be the one that deployed it.',
      );
    }

    final host = Uri.parse(_pocketBase.baseURL).host;
    if (host.isEmpty) {
      throw ServerUpdateException('No known server host to connect to.');
    }

    final keyPairs = SSHKeyPair.fromPem(credentials.rootSshPrivateKey);
    if (keyPairs.isEmpty) {
      throw ServerUpdateException('Stored root SSH key could not be parsed.');
    }

    final socket = await SSHSocket.connect(host, _kSshPort);
    final client = SSHClient(
      socket,
      username: 'root',
      identities: keyPairs,
    );

    try {
      await client.authenticated;

      final session = await client.execute(_kUpdateCommand);

      final stdoutBytes = BytesBuilder();
      final stderrBytes = BytesBuilder();
      final stdoutDone = session.stdout.listen(stdoutBytes.add).asFuture();
      final stderrDone = session.stderr.listen(stderrBytes.add).asFuture();
      await session.done;
      await Future.wait([stdoutDone, stderrDone]);

      return ServerUpdateResult(
        exitCode: session.exitCode ?? -1,
        stdout: utf8.decode(stdoutBytes.toBytes(), allowMalformed: true),
        stderr: utf8.decode(stderrBytes.toBytes(), allowMalformed: true),
      );
    } finally {
      client.close();
    }
  }
}
