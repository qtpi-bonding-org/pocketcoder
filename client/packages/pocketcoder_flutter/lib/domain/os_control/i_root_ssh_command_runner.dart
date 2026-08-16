import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command_result.dart';

import 'dart:typed_data';

/// Executes PocketCoder's small, reviewed root-SSH command set.
abstract interface class IRootSshCommandRunner {
  Future<RootSshCommandResult> run({
    required String instanceId,
    required String host,
    required RootSshCommand command,
    Uint8List? stdin,
  });
}
