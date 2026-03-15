class ToolPermissionsException implements Exception {
  final String message;
  final Object? cause;

  ToolPermissionsException(this.message, {this.cause});

  @override
  String toString() => 'ToolPermissionsException: $message';
}
