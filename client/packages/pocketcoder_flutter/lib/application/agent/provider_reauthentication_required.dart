final class ProviderReauthenticationRequired implements Exception {
  const ProviderReauthenticationRequired();

  // Without this, reaching UiFlowListener's fallback (or any other direct
  // toString() call) renders as Dart's default Object.toString(),
  // "Instance of 'ProviderReauthenticationRequired'", directly in the UI --
  // confirmed live. AppExceptionKeyMapper maps this to the dedicated,
  // already-localized `provider.reauthentication.required` string; this
  // toString() is only a defense-in-depth fallback for any path that
  // stringifies the error directly instead of going through the mapper.
  @override
  String toString() => 'Provider reauthentication required';
}
