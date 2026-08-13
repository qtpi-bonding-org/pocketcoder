/// Supplies the root SSH key retained for a user-owned PocketCoder server.
///
/// The public control implementations depend on this narrow contract so an
/// app distribution can choose its own secure-storage implementation.
abstract interface class IRootSshKeyProvider {
  Future<String?> readRootSshPrivateKey({required String instanceId});
}
