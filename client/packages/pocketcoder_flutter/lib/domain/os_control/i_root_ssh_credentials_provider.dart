import 'package:pocketcoder_flutter/domain/os_control/root_ssh_credentials.dart';

/// Supplies root SSH credentials retained for a user-owned PocketCoder server.
///
/// The public control implementations depend on this narrow contract so an
/// app distribution can choose its own secure-storage implementation.
abstract interface class IRootSshCredentialsProvider {
  Future<RootSshCredentials?> readRootSshCredentials({
    required String instanceId,
  });
}
