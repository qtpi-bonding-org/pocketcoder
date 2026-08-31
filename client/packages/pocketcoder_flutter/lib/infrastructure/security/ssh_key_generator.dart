import 'package:cryptography/cryptography.dart';
import 'package:injectable/injectable.dart';
import 'package:openssh_ed25519/openssh_ed25519.dart';

import 'package:pocketcoder_flutter/domain/security/i_ssh_key_generator.dart';

@LazySingleton(as: ISshKeyGenerator)
class SshKeyGenerator implements ISshKeyGenerator {
  @override
  Future<({String publicKey, String privateKey})> generate() async {
    return _generateKeyPair();
  }

  @override
  Future<({String publicKey, String privateKey})> generateHostKeyPair() async {
    return _generateKeyPair();
  }

  Future<({String publicKey, String privateKey})> _generateKeyPair() async {
    final keyPair = await Ed25519().newKeyPair();
    final privateBytes = await keyPair.extractPrivateKeyBytes();
    final publicKeyObj = await keyPair.extractPublicKey();
    final publicBytes = publicKeyObj.bytes;

    // Trim: this must survive as a single line in the base64-encoded
    // user-data env file (one `root_ssh_key=<value>` line) -- a trailing
    // newline from the encoder would otherwise corrupt that format.
    final publicKey = encodeEd25519Public(publicBytes).trim();
    final privateKey = encodeEd25519Private(
      privateBytes: privateBytes,
      publicBytes: publicBytes,
    );

    return (publicKey: publicKey, privateKey: privateKey);
  }
}
