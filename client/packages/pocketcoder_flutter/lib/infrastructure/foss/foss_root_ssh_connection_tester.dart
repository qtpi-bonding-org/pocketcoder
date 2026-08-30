import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_exception.dart';

final class FossHostIdentity {
  const FossHostIdentity({
    required this.hostKeyType,
    required this.hostKeyFingerprint,
  });

  final String hostKeyType;
  final String hostKeyFingerprint;
}

// Interface separate from the impl so tests can mock it.
abstract interface class IFossRootSshConnectionTester {
  Future<FossHostIdentity> testConnection({
    required String host,
    required String privateKeyPem,
  });
}

final class FossRootSshConnectionTester
    implements IFossRootSshConnectionTester {
  static const _sshPort = 22;
  static const _connectTimeout = Duration(seconds: 15);

  @override
  Future<FossHostIdentity> testConnection({
    required String host,
    required String privateKeyPem,
  }) async {
    if (host.isEmpty) {
      throw const RootSshException('No server host to connect to.');
    }

    late final List<SSHKeyPair> keyPairs;
    try {
      keyPairs = SSHKeyPair.fromPem(privateKeyPem);
    } on Object {
      throw const RootSshException(
          'The generated SSH key could not be parsed.');
    }
    if (keyPairs.isEmpty) {
      throw const RootSshException(
          'The generated SSH key could not be parsed.');
    }

    final SSHSocket socket;
    try {
      socket =
          await SSHSocket.connect(host, _sshPort, timeout: _connectTimeout);
    } on Object catch (error) {
      throw RootSshException('Could not connect: $error');
    }

    String? capturedType;
    Uint8List? capturedFingerprint;
    final client = SSHClient(
      socket,
      username: 'root',
      identities: keyPairs,
      onVerifyHostKey: (type, fingerprint) {
        capturedType = type;
        capturedFingerprint = fingerprint;
        return true;
      },
    );

    try {
      await client.authenticated;
      final session = await client.execute('whoami');
      final stdoutBytes = BytesBuilder();
      await session.stdout.listen(stdoutBytes.add).asFuture<void>();
      await session.done;
      final whoami = utf8.decode(stdoutBytes.toBytes()).trim();
      if (whoami != 'root') {
        throw RootSshException(
          'Connected, but authenticated as "$whoami", not root.',
        );
      }

      final type = capturedType;
      final fingerprint = capturedFingerprint;
      if (type == null || fingerprint == null) {
        throw const RootSshException(
          'Could not read the server\'s SSH host identity.',
        );
      }
      return FossHostIdentity(
        hostKeyType: type,
        hostKeyFingerprint: utf8.decode(fingerprint),
      );
    } on RootSshException {
      rethrow;
    } on Object catch (error) {
      throw RootSshException('Could not connect: $error');
    } finally {
      client.close();
    }
  }
}
