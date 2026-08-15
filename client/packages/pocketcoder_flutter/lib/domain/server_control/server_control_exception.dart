final class ServerControlException implements Exception {
  const ServerControlException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'ServerControlException: $message';
}
