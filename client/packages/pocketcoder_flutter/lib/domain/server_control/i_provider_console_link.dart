abstract interface class IProviderConsoleLink {
  /// A link to the active deployment's page on its cloud provider's own
  /// web dashboard, or null when there's no active provider-managed
  /// instance to link to.
  Future<Uri?> resolve();
}
