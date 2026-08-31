abstract interface class ILocalAuthGate {
  /// Returns true only if the device's local auth (biometric or device
  /// passcode) succeeded. Any failure, cancellation, or platform error
  /// resolves to false rather than throwing -- callers treat it as "don't
  /// reveal," not as an app error.
  Future<bool> authenticate({required String reason});
}
