class ProviderException implements Exception {
  final String message;
  final Object? cause;

  ProviderException(this.message, [this.cause]);

  @override
  String toString() => 'ProviderException: $message';
}
