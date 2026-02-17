class SubagentException implements Exception {
  final String message;
  final Object? cause;

  SubagentException(this.message, {this.cause});

  @override
  String toString() => 'SubagentException: $message';
}