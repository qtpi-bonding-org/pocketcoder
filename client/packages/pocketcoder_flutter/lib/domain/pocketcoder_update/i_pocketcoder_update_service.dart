import 'package:pocketcoder_flutter/domain/release/server_release_status.dart';

import 'pocketcoder_update_exception.dart';
import 'pocketcoder_update_result.dart';

/// User-initiated control surface for inspecting and updating PocketCoder.
///
/// The public package owns this contract. A distribution decides how to reach
/// the user's server and run the native release manager.
abstract interface class IPocketCoderUpdateService {
  /// Reads the OS-verified release status cached by the deployment.
  /// This never initiates an update.
  Future<ServerReleaseStatusSnapshot> inspect();

  /// Runs the verified PocketCoder release updater for [instanceId].
  ///
  /// A command that runs and reports failure returns a normal result. An
  /// inability to attempt it, such as unavailable credentials, throws a
  /// [PocketCoderUpdateException].
  Future<PocketCoderUpdateResult> updatePocketCoder({
    required String instanceId,
  });
}
