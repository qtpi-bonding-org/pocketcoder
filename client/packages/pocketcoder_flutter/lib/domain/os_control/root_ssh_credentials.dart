/// Credentials and pinned server identity for privileged owner SSH.
///
/// The private key authenticates the phone to the user's VPS. The host-key
/// fields authenticate that VPS back to the phone; both are required before a
/// privileged command may run.
final class RootSshCredentials {
  const RootSshCredentials({
    required this.privateKeyPem,
    required this.hostKeyType,
    required this.hostKeyFingerprint,
  });

  final String privateKeyPem;
  final String hostKeyType;

  /// OpenSSH MD5 fingerprint (`MD5:aa:bb:...`) supplied by dartssh2's host-key
  /// verification callback.
  final String hostKeyFingerprint;
}
