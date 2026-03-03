class SandboxAgentException implements Exception {
  final String message;
  final Object? cause;

  SandboxAgentException(this.message, {this.cause});

  @override
  String toString() => 'SandboxAgentException: $message';
}
