import 'deployment_phase.dart';
import 'server_status_document.dart';

/// One observation made while waiting for a newly provisioned server.
///
/// [statusDocument] is the complete document returned by the VPS. Keeping it
/// attached to the update prevents phase details and future schema fields from
/// being lost while the client derives its simpler [phase].
class DeploymentReadinessUpdate {
  const DeploymentReadinessUpdate({
    required this.phase,
    required this.pollingAttempt,
    this.statusDocument,
  });

  final DeploymentPhase phase;
  final int pollingAttempt;
  final ServerStatusDocument? statusDocument;
}
