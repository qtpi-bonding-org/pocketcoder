class PermissionException implements Exception {
  final String message;
  final Object? cause;

  PermissionException(this.message, {this.cause});

  @override
  String toString() => 'PermissionException: $message';
}