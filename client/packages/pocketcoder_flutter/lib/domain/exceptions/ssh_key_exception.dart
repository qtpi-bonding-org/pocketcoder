class SSHKeyException implements Exception {
  final String message;
  final Object? cause;

  SSHKeyException(this.message, {this.cause});

  @override
  String toString() => 'SSHKeyException: $message';
}