/// Why a [CertificateRecoveryService] cache/restore attempt ended the way it
/// did. Both operations are best-effort and must never throw for expected
/// outcomes -- a failed cache/restore falls back to normal ACME issuance.
enum CertificateRecoveryOutcome {
  succeeded,
  sshFailed,
  malformedBundle,
  noBundleAvailable,
}

final class CertificateRecoveryResult {
  const CertificateRecoveryResult({required this.outcome, this.reason});

  final CertificateRecoveryOutcome outcome;

  /// Technical label only (e.g. an exception type name or exit code) -- safe
  /// to log, never user data.
  final String? reason;

  bool get succeeded => outcome == CertificateRecoveryOutcome.succeeded;
}
