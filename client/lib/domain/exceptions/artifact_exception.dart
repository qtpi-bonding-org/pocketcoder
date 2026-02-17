class ArtifactException implements Exception {
  final String message;
  final Object? cause;

  ArtifactException(this.message, {this.cause});

  @override
  String toString() => 'ArtifactException: $message';
}