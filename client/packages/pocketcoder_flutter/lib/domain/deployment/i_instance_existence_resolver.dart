/// Lets generic boot/onboarding flow ask the managed deployment engine to
/// resolve a stale session when its backing instance no longer exists,
/// without depending on `pocketcoder_pro`'s deployment engine types.
///
/// Registered in DI only by builds that have a managed deployment flow
/// (pocketcoder_pro); absent in the OSS/self-host build, where callers
/// must guard with `getIt.isRegistered<IInstanceExistenceResolver>()`.
abstract interface class IInstanceExistenceResolver {
  Future<bool> resolveStaleSessionIfInstanceGone();
}
