import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:meta/meta.dart';
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
    'if [ -x /opt/pocketcoder/current/bin/pocketcoder-release ]; '
    'then /opt/pocketcoder/current/bin/pocketcoder-release restart-pocketcoder; '
    'else echo "PocketCoder release manager was not found" >&2; exit 1; fi';

const _restartNixOsCommand =
    'if [ -x /opt/pocketcoder/current/bin/pocketcoder-release ]; '
    'then /opt/pocketcoder/current/bin/pocketcoder-release restart-os; '
    'else echo "PocketCoder release manager was not found" >&2; exit 1; fi';
const _updateNixOsCommand =
    'if [ -x /opt/pocketcoder/current/bin/pocketcoder-release ]; '
    'then /opt/pocketcoder/current/bin/pocketcoder-release update-os; '
    'else echo "PocketCoder release manager was not found" >&2; exit 1; fi';
const _saveBackupCommand =
    'if [ -x /opt/pocketcoder/current/bin/pocketcoder-release ]; '
    'then /opt/pocketcoder/current/bin/pocketcoder-release backup-data; '
    'else echo "PocketCoder release manager was not found" >&2; exit 1; fi';
const _exportCaddyCertificateCommand =
    'if [ -x /opt/pocketcoder/current/bin/pocketcoder-release ]; '
    'then /opt/pocketcoder/current/bin/pocketcoder-release export-cert; '
    'else echo "PocketCoder release manager was not found" >&2; exit 1; fi';
const _restoreCaddyCertificateCommand =
    'if [ -x /opt/pocketcoder/current/bin/pocketcoder-release ]; '
    'then /opt/pocketcoder/current/bin/pocketcoder-release import-cert; '
    'else echo "PocketCoder release manager was not found" >&2; exit 1; fi';
const _rollbackCommand =
    'if [ -x /opt/pocketcoder/current/bin/pocketcoder-release ]; '
    'then /opt/pocketcoder/current/bin/pocketcoder-release rollback; '
    'else echo "PocketCoder release manager was not found" >&2; exit 1; fi';

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
    Uint8List? stdin,
    String? shellEnvPrefix,
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

    final expectedFingerprint = parseFingerprint(
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
      final shellCommand = _shellCommand(command);
      final session = await client.execute(
        shellEnvPrefix != null && shellEnvPrefix.isNotEmpty
            ? '$shellEnvPrefix$shellCommand'
            : shellCommand,
      );
      if (stdin != null) {
        await Stream<Uint8List>.value(stdin).pipe(session.stdin);
      }
      final stdoutBytes = BytesBuilder();
      final stderrBytes = BytesBuilder();
      final stdoutDone = session.stdout
          .listen(stdoutBytes.add)
          .asFuture<void>();
      final stderrDone = session.stderr
          .listen(stderrBytes.add)
          .asFuture<void>();
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
    RootSshCommand.exportCaddyCertificate => _exportCaddyCertificateCommand,
    RootSshCommand.restoreCaddyCertificate => _restoreCaddyCertificateCommand,
    RootSshCommand.rollback => _rollbackCommand,
  };

  // dartssh2's onVerifyHostKey passes the SHA256 fingerprint as the literal
  // UTF-8 bytes of "SHA256:<base64>" (see SSHHostkeyVerifyHandler's doc
  // comment and _hostkeyFingerprint in its own ssh_transport.dart) -- not
  // a decoded MD5 digest. Confirmed live: comparing against a decoded MD5
  // digest meant this could never match, so every host-key verification
  // silently failed and dartssh2 closed the connection before ever
  // attempting authentication. Not private (but not part of the public
  // API contract either) so a test can assert this produces exactly what
  // dartssh2 itself compares against -- that's the one guarantee that
  // actually matters here, and this bug shipped once already without it.
  @visibleForTesting
  static Uint8List? parseFingerprint(String value) {
    if (!value.startsWith('SHA256:') || value.length <= 'SHA256:'.length) {
      return null;
    }
    return Uint8List.fromList(utf8.encode(value));
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
