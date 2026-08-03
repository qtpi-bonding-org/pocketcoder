/// Result of running the update command (`git pull && docker compose
/// --profile harness-images build && docker compose up -d`) on the deployed
/// server over SSH.
class ServerUpdateResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const ServerUpdateResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  bool get succeeded => exitCode == 0;
}
