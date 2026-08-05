/// Harness authentication lifecycle domain exception.
class HarnessAuthException implements Exception {
  final String message;
  final Object? cause;

  HarnessAuthException(this.message, [this.cause]);

  factory HarnessAuthException.notAuthenticated([dynamic cause]) =>
      HarnessAuthException('Authentication required', cause);

  @override
  String toString() => 'HarnessAuthException: $message';
}
