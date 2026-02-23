class WhitelistException implements Exception {
  final String message;
  final Object? cause;

  WhitelistException(this.message, {this.cause});

  @override
  String toString() => 'WhitelistException: $message';
}