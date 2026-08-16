import 'dart:convert';

import 'package:pocketcoder_flutter/domain/deployment/certificate_bundle.dart';
import 'package:pocketcoder_flutter/domain/deployment/certificate_recovery_result.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_command_runner.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/certificate_bundle_store.dart';

/// Performs the certificate handoff over the existing authenticated SSH
/// channel. The bundle is never sent through HTTP or the public status file.
///
/// Every outcome -- including SSH and parse failures -- comes back as a
/// [CertificateRecoveryResult] rather than a thrown exception, because both
/// operations are best-effort: a failure here must fall back to normal ACME
/// issuance, not fail the deployment.
final class CertificateRecoveryService {
  const CertificateRecoveryService({
    required IRootSshCommandRunner ssh,
    required CertificateBundleStore store,
  }) : _ssh = ssh,
       _store = store;

  final IRootSshCommandRunner _ssh;
  final CertificateBundleStore _store;

  Future<CertificateRecoveryResult> cache({
    required String deploymentId,
    required String host,
  }) async {
    try {
      final result = await _ssh.run(
        instanceId: deploymentId,
        host: host,
        command: RootSshCommand.exportCaddyCertificate,
      );
      if (result.exitCode != 0) {
        return CertificateRecoveryResult(
          outcome: CertificateRecoveryOutcome.sshFailed,
          reason: 'exportCaddyCertificate exited ${result.exitCode}',
        );
      }
      final bundle = CertificateBundle.fromJson(
        jsonDecode(result.stdout) as Map<String, dynamic>,
      );
      await _store.write(deploymentId: deploymentId, bundle: bundle);
      return const CertificateRecoveryResult(
        outcome: CertificateRecoveryOutcome.succeeded,
      );
    } on FormatException catch (e) {
      return CertificateRecoveryResult(
        outcome: CertificateRecoveryOutcome.malformedBundle,
        reason: e.runtimeType.toString(),
      );
    } on Object catch (e) {
      return CertificateRecoveryResult(
        outcome: CertificateRecoveryOutcome.sshFailed,
        reason: e.runtimeType.toString(),
      );
    }
  }

  Future<CertificateRecoveryResult> restore({
    required String deploymentId,
    required String host,
    required String hostname,
  }) async {
    final bundle = await _store.read(
      deploymentId: deploymentId,
      hostname: hostname,
    );
    if (bundle == null) {
      return const CertificateRecoveryResult(
        outcome: CertificateRecoveryOutcome.noBundleAvailable,
      );
    }
    try {
      final result = await _ssh.run(
        instanceId: deploymentId,
        host: host,
        command: RootSshCommand.restoreCaddyCertificate,
        stdin: bundle.encodedJson,
      );
      if (result.exitCode != 0) {
        return CertificateRecoveryResult(
          outcome: CertificateRecoveryOutcome.sshFailed,
          reason: 'restoreCaddyCertificate exited ${result.exitCode}',
        );
      }
      return const CertificateRecoveryResult(
        outcome: CertificateRecoveryOutcome.succeeded,
      );
    } on Object catch (e) {
      return CertificateRecoveryResult(
        outcome: CertificateRecoveryOutcome.sshFailed,
        reason: e.runtimeType.toString(),
      );
    }
  }
}
