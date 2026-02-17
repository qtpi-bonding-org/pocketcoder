class UserException implements Exception {
  final String message;
  final Object? cause;

  UserException(this.message, {this.cause});

  @override
  String toString() => 'UserException: $message';
}