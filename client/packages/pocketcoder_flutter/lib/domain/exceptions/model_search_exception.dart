class ModelSearchException implements Exception {
  final String message;
  final Object? cause;

  ModelSearchException(this.message, [this.cause]);

  @override
  String toString() => 'ModelSearchException: $message';
}
