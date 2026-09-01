import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command_result.dart';

import 'dart:typed_data';

/// Executes PocketCoder's small, reviewed root-SSH command set.
abstract interface class IRootSshCommandRunner {
  /// Fetches only the bounded provisioning window; unlike [run], this
  /// command has reviewed runtime time bounds and is not a free-form shell API.
  Future<RootSshCommandResult> fetchProvisioningLogs({
    required String instanceId,
    required String host,
    required DateTime since,
    required DateTime until,
  });

  Future<RootSshCommandResult> run({
    required String instanceId,
    required String host,
    required RootSshCommand command,
    Uint8List? stdin,

    /// Narrow escape hatch for branch selection on updatePocketCoder, whose
    /// reviewed command text does not set the required remote environment
    /// variable. This is not a general shell-injection API: callers still
    /// cannot supply arbitrary commands, only an environment-variable prefix.
    String? shellEnvPrefix,
  });
}
