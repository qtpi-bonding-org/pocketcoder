class AiModelException implements Exception {
  final String message;
  final Object? cause;

  AiModelException(this.message, {this.cause});

  @override
  String toString() => 'AiModelException: $message';
}