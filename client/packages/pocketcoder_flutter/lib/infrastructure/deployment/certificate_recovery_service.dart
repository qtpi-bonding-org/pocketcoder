import 'dart:convert';

import 'package:pocketcoder_flutter/domain/deployment/certificate_bundle.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_command_runner.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/certificate_bundle_store.dart';

/// Performs the certificate handoff over the existing authenticated SSH
/// channel. The bundle is never sent through HTTP or the public status file.
final class CertificateRecoveryService {
  const CertificateRecoveryService({
    required IRootSshCommandRunner ssh,
    required CertificateBundleStore store,
  }) : _ssh = ssh,
       _store = store;

  final IRootSshCommandRunner _ssh;
  final CertificateBundleStore _store;

  Future<bool> cache({
    required String deploymentId,
    required String host,
  }) async {
    final result = await _ssh.run(
      instanceId: deploymentId,
      host: host,
      command: RootSshCommand.exportCaddyCertificate,
    );
    if (result.exitCode != 0) return false;
    try {
      final bundle = CertificateBundle.fromJson(
        jsonDecode(result.stdout) as Map<String, dynamic>,
      );
      await _store.write(deploymentId: deploymentId, bundle: bundle);
      return true;
    } on Object {
      return false;
    }
  }

  Future<bool> restore({
    required String deploymentId,
    required String host,
    required String hostname,
  }) async {
    final bundle = await _store.read(
      deploymentId: deploymentId,
      hostname: hostname,
    );
    if (bundle == null || bundle.hostname != hostname) return false;
    final result = await _ssh.run(
      instanceId: deploymentId,
      host: host,
      command: RootSshCommand.restoreCaddyCertificate,
      stdin: bundle.encodedJson,
    );
    return result.exitCode == 0;
  }
}
