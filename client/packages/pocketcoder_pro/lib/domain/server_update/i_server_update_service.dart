import 'server_update_result.dart';

/// Updates the deployed server by SSHing in as root and running
/// the verified, prebuilt PocketCoder release updater.
///
/// Deliberately user-initiated only (a button in the app) -- no background
/// polling, no silent auto-update. Independent of pocketcoder_flutter's
/// SshTerminalCubit (a separate, non-root, sandboxed `worker`-user SSH
/// connection for an unrelated feature): this uses the root credentials
/// Aeroform generated at deploy time, over a plain non-interactive SSH exec,
/// not an interactive PTY.
abstract class IServerUpdateService {
  /// Runs the release updater against the given instance. Throws
  /// [ServerUpdateException] if no stored root credentials or server host
  /// are available for this instance -- otherwise returns a
  /// [ServerUpdateResult] reflecting whatever the command itself did
  /// (success or failure is not an exception; it's the normal result).
  Future<ServerUpdateResult> updateServer({required String instanceId});
}
