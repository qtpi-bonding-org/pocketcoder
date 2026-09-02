/// Lets generic boot/onboarding flow ask the managed deployment engine
/// whether the session's backing instance still exists, without depending
/// on `pocketcoder_pro`'s deployment engine types.
///
/// Registered in DI only by builds that have a managed deployment flow
/// (pocketcoder_pro); absent in the OSS/self-host build, where callers
/// must guard with `getIt.isRegistered<IInstanceExistenceResolver>()`.
enum InstanceExistenceResult {
  exists,

  /// The provider confirms the instance is gone. A call that returns this
  /// has already performed the ordered local clear (deployment state,
  /// active-instance record, readiness re-check, then session) as a side
  /// effect -- callers don't need to clear anything themselves.
  gone,

  /// No definitive answer could be obtained (no provider credential, a
  /// provider API error, a timeout, etc). Never treated as "confirmed
  /// gone" -- nothing is cleared.
  unknown,
}

abstract interface class IInstanceExistenceResolver {
  Future<InstanceExistenceResult> checkInstanceExists();
}
