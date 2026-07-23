class AgentConfigException implements Exception {
  final String message;
  final Object? cause;

  AgentConfigException(this.message, [this.cause]);

  @override
  String toString() => 'AgentConfigException: $message';
}
