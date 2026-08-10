/// Thrown when the verified server update can't
/// even be attempted -- no stored root credentials for this instance, or no
/// known server URL to derive the SSH host from. Distinct from the command
/// itself running but failing (see [ServerUpdateResult.succeeded]), which is
/// a normal, non-exceptional outcome shown to the user as command output.
class ServerUpdateException implements Exception {
  final String message;

  ServerUpdateException(this.message);

  @override
  String toString() => 'ServerUpdateException: $message';
}
