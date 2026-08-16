import 'dart:io';
import 'dart:typed_data';

import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_credentials_provider.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_credentials.dart';
import 'package:pocketcoder_flutter/infrastructure/os_control/ssh_root_command_runner.dart';

final class _CliCredentialsProvider implements IRootSshCredentialsProvider {
  const _CliCredentialsProvider({
    required this.privateKeyPem,
    required this.hostKeyType,
    required this.hostKeyFingerprint,
  });

  final String privateKeyPem;
  final String hostKeyType;
  final String hostKeyFingerprint;

  @override
  Future<RootSshCredentials> readRootSshCredentials({
    required String instanceId,
  }) async => RootSshCredentials(
    privateKeyPem: privateKeyPem,
    hostKeyType: hostKeyType,
    hostKeyFingerprint: hostKeyFingerprint,
  );
}

Future<void> main(List<String> arguments) async {
  final options = _parseOptions(arguments);
  final commandName = options['command'];
  final host = options['host'];
  final keyPath = options['key'];
  final hostKeyType = options['host-key-type'];
  final hostKeyFingerprint = options['host-key-fingerprint'];
  final shellEnvPrefix = options['shell-env-prefix'];
  if (commandName == null ||
      host == null ||
      keyPath == null ||
      hostKeyType == null ||
      hostKeyFingerprint == null) {
    stderr.writeln(
      'usage: root_ssh_command.dart --command <name> --host <ip> '
      '--key <path> --host-key-type <type> '
      '--host-key-fingerprint <MD5:...>',
    );
    exitCode = 64;
    return;
  }

  final command = _commandByName(commandName);
  if (command == null) {
    stderr.writeln('unknown root SSH command: $commandName');
    exitCode = 64;
    return;
  }

  Uint8List? stdinBytes;
  if (command == RootSshCommand.restoreCaddyCertificate) {
    final input = BytesBuilder();
    while (true) {
      final byte = stdin.readByteSync();
      if (byte == -1) break;
      input.addByte(byte);
    }
    stdinBytes = input.takeBytes();
  }

  final runner = SshRootCommandRunner(
    credentialsProvider: _CliCredentialsProvider(
      privateKeyPem: File(keyPath).readAsStringSync(),
      hostKeyType: hostKeyType,
      hostKeyFingerprint: hostKeyFingerprint,
    ),
  );
  final result = await runner.run(
    instanceId: 'cli',
    host: host,
    command: command,
    stdin: stdinBytes,
    shellEnvPrefix: shellEnvPrefix,
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  exit(result.exitCode);
}

Map<String, String> _parseOptions(List<String> arguments) {
  final options = <String, String>{};
  for (var index = 0; index + 1 < arguments.length; index += 2) {
    final argument = arguments[index];
    if (!argument.startsWith('--')) continue;
    options[argument.substring(2)] = arguments[index + 1];
  }
  return options;
}

RootSshCommand? _commandByName(String name) {
  for (final command in RootSshCommand.values) {
    if (command.name == name) return command;
  }
  return null;
}
