import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';

final class ServerControlResult {
  const ServerControlResult({
    required this.command,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final RootSshCommand command;
  final int exitCode;
  final String stdout;
  final String stderr;

  bool get succeeded => exitCode == 0;
}
