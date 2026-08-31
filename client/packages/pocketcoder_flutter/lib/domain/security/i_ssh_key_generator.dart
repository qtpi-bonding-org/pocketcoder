abstract class ISshKeyGenerator {
  Future<({String publicKey, String privateKey})> generate();

  /// Distinct from [generate] so callers can't confuse a client key with a
  /// host key.
  Future<({String publicKey, String privateKey})> generateHostKeyPair();
}
