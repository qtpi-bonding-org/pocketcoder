/// Result returned by the native PocketCoder release updater.
class PocketCoderUpdateResult {
  const PocketCoderUpdateResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;

  bool get succeeded => exitCode == 0;
}
