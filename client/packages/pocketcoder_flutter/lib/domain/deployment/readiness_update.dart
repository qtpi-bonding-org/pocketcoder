import 'package:pocketcoder_flutter/domain/deployment/deploy_operation_key.dart';
import 'package:pocketcoder_flutter/domain/deployment/server_status_document.dart';

/// One observation made while waiting for a newly provisioned server.
///
/// [statusDocument] is the complete document returned by the VPS. Keeping it
/// attached to the update prevents operation details and future schema
/// fields from being lost while the client derives its simpler
/// [operationKey].
class ReadinessUpdate {
  const ReadinessUpdate({
    required this.operationKey,
    required this.pollingAttempt,
    required this.statusTransportAuthenticated,
    required this.statusDocument,
  });

  final DeployOperationKey operationKey;
  final int pollingAttempt;
  final bool statusTransportAuthenticated;
  final ServerStatusDocument? statusDocument;

  /// True when [statusDocument] carries an error that has exhausted its
  /// retries (`attempt >= maxAttempts`) -- the point at which the monitor's
  /// stream actually terminates. A non-null `statusDocument?.errorCode` with
  /// this false means a transient, still-retrying error: the monitor is
  /// still polling and a consumer must not treat it as a failure yet.
  bool get isTerminalError {
    final doc = statusDocument;
    if (doc == null) return false;
    return doc.errorCode != null && doc.attempt >= doc.maxAttempts;
  }
}
