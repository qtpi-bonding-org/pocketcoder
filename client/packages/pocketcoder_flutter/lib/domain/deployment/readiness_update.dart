import 'package:pocketcoder_flutter/domain/deployment/readiness_phase.dart';
import 'package:pocketcoder_flutter/domain/deployment/server_status_document.dart';

/// One observation made while waiting for a newly provisioned server.
///
/// [statusDocument] is the complete document returned by the VPS. Keeping it
/// attached to the update prevents phase details and future schema fields from
/// being lost while the client derives its simpler [phase].
class ReadinessUpdate {
  const ReadinessUpdate({
    required this.phase,
    required this.pollingAttempt,
    required this.statusTransportAuthenticated,
    required this.statusDocument,
  });

  final ReadinessPhase phase;
  final int pollingAttempt;
  final bool statusTransportAuthenticated;
  final ServerStatusDocument? statusDocument;
}
