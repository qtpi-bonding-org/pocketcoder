final class RootSshException implements Exception {
  const RootSshException(this.message);

  final String message;

  @override
  String toString() => message;
}
