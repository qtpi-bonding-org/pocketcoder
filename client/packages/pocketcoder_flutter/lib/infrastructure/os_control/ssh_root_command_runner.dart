import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_command_runner.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_credentials_provider.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command_result.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_exception.dart';

const _updatePocketCoderCommand =
    'if [ -x /opt/pocketcoder/current/bin/pocketcoder-release ]; '
    'then /opt/pocketcoder/current/bin/pocketcoder-release update; '
    'else echo "PocketCoder release manager was not found" >&2; exit 1; fi';

const _restartPocketCoderCommand =
    'if [ -f /opt/pocketcoder/current/docker-compose.prebuilt.yml ]; '
    'then if docker compose version >/dev/null 2>&1; '
    'then docker compose --project-name pocketcoder '
    '--env-file /var/lib/pocketcoder/config/runtime.env '
    '-f /opt/pocketcoder/current/docker-compose.prebuilt.yml restart; '
    'else docker-compose --project-name pocketcoder '
    '--env-file /var/lib/pocketcoder/config/runtime.env '
    '-f /opt/pocketcoder/current/docker-compose.prebuilt.yml restart; fi; '
    'else echo "PocketCoder Compose release was not found" >&2; exit 1; fi';

const _restartNixOsCommand = 'systemctl reboot';
const _updateNixOsCommand = 'nixos-rebuild switch --upgrade';
const _saveBackupCommand =
    'docker exec pocketcoder-pocketbase /app/backup_db.sh';

/// Root SSH transport shared by the small set of owner recovery operations.
///
/// UI and Cubits select a typed [RootSshCommand]; they never provide shell
/// text. Every connection verifies the SSH server identity captured over the
/// deployment's authenticated HTTPS readiness channel.
final class SshRootCommandRunner implements IRootSshCommandRunner {
  const SshRootCommandRunner({
    required IRootSshCredentialsProvider credentialsProvider,
  }) : _credentialsProvider = credentialsProvider;

  static const _sshPort = 22;
  static const _connectTimeout = Duration(seconds: 15);

  final IRootSshCredentialsProvider _credentialsProvider;

  @override
  Future<RootSshCommandResult> run({
    required String instanceId,
    required String host,
    required RootSshCommand command,
  }) async {
    if (host.isEmpty) {
      throw const RootSshException('No known server host to connect to.');
    }

    final credentials = await _credentialsProvider.readRootSshCredentials(
      instanceId: instanceId,
    );
    if (credentials == null || credentials.privateKeyPem.isEmpty) {
      throw const RootSshException(
        'No stored root credentials are available on this device.',
      );
    }

    final expectedFingerprint = _parseFingerprint(
      credentials.hostKeyFingerprint,
    );
    if (credentials.hostKeyType.isEmpty || expectedFingerprint == null) {
      throw const RootSshException(
        'The server SSH identity is missing or invalid.',
      );
    }

    late final List<SSHKeyPair> keyPairs;
    try {
      keyPairs = SSHKeyPair.fromPem(credentials.privateKeyPem);
    } on Object {
      throw const RootSshException('Stored root SSH key could not be parsed.');
    }
    if (keyPairs.isEmpty) {
      throw const RootSshException('Stored root SSH key could not be parsed.');
    }

    final socket = await SSHSocket.connect(
      host,
      _sshPort,
      timeout: _connectTimeout,
    );
    final client = SSHClient(
      socket,
      username: 'root',
      identities: keyPairs,
      onVerifyHostKey: (type, fingerprint) =>
          type == credentials.hostKeyType &&
          _constantTimeEquals(fingerprint, expectedFingerprint),
    );

    try {
      await client.authenticated;
      final session = await client.execute(_shellCommand(command));
      final stdoutBytes = BytesBuilder();
      final stderrBytes = BytesBuilder();
      final stdoutDone =
          session.stdout.listen(stdoutBytes.add).asFuture<void>();
      final stderrDone =
          session.stderr.listen(stderrBytes.add).asFuture<void>();
      await session.done;
      await Future.wait([stdoutDone, stderrDone]);

      return RootSshCommandResult(
        exitCode: session.exitCode ?? -1,
        stdout: utf8.decode(stdoutBytes.toBytes(), allowMalformed: true),
        stderr: utf8.decode(stderrBytes.toBytes(), allowMalformed: true),
      );
    } finally {
      client.close();
    }
  }

  static String _shellCommand(RootSshCommand command) => switch (command) {
        RootSshCommand.restartPocketCoder => _restartPocketCoderCommand,
        RootSshCommand.updatePocketCoder => _updatePocketCoderCommand,
        RootSshCommand.restartNixOs => _restartNixOsCommand,
        RootSshCommand.updateNixOs => _updateNixOsCommand,
        RootSshCommand.saveBackup => _saveBackupCommand,
      };

  static Uint8List? _parseFingerprint(String value) {
    final normalized = value.startsWith('MD5:') ? value.substring(4) : value;
    final components = normalized.split(':');
    if (components.length != 16) return null;
    final bytes = Uint8List(components.length);
    for (var index = 0; index < components.length; index += 1) {
      final component = components[index];
      if (component.length != 2) return null;
      final byte = int.tryParse(component, radix: 16);
      if (byte == null) return null;
      bytes[index] = byte;
    }
    return bytes;
  }

  static bool _constantTimeEquals(Uint8List actual, Uint8List expected) {
    if (actual.length != expected.length) return false;
    var difference = 0;
    for (var index = 0; index < actual.length; index += 1) {
      difference |= actual[index] ^ expected[index];
    }
    return difference == 0;
  }
}
