/// Provides deployment connection details without coupling the shared Flutter
/// package to a particular deployment implementation.
///
/// Implementations are supplied by application packages such as
/// `pocketcoder_pro`. Self-hosted implementations may omit credentials.
abstract interface class IServerConnectionDetailsProvider {
  /// Whether there is any connection information worth showing.
  bool get isAvailable;

  String? get ipAddress;
  String? get httpsEndpoint;
  String? get adminIdentity;
  String? get adminPassword;
}
