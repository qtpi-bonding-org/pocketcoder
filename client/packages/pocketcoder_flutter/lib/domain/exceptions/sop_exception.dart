class SOPException implements Exception {
  final String message;
  final Object? cause;

  SOPException(this.message, {this.cause});

  @override
  String toString() => 'SOPException: $message';
}