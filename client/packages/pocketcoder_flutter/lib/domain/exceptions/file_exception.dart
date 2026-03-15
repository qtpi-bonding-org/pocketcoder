class FileException implements Exception {
  final String message;
  final Object? cause;

  FileException(this.message, {this.cause});

  @override
  String toString() => 'FileException: $message';
}
