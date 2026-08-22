import 'dart:convert';

import 'package:pocketcoder_flutter/domain/deployment/caddy_ca_pin.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_command_runner.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/ca_pin_mutex.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/caddy_ca_pin_store.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/diagnostic_capture.dart';

/// Narrow interface for updating the CA pin used by the HTTP client.
///
/// The concrete Caddy client is final, so production wiring should use
/// [CaddyCaPinningHttpClientAdapter] rather than subclassing it.
abstract class CaPinWriter {
  void updatePin(String certificatePem);
}

/// Composition adapter around the production Caddy pinning HTTP client.
class CaddyCaPinningHttpClientAdapter implements CaPinWriter {
  CaddyCaPinningHttpClientAdapter(this._client);

  final dynamic _client;

  @override
  void updatePin(String certificatePem) => _client.updatePin(certificatePem);
}

/// Fetches and durably stores Caddy's CA pin without duplicate writes.
class CaPinFetcher {
  CaPinFetcher({
    required this.sshCommandRunner,
    required this.pinStore,
    required this.pinningHttpClient,
    required this.mutex,
  });

  final IRootSshCommandRunner sshCommandRunner;
  final CaddyCaPinStore pinStore;
  final CaPinWriter pinningHttpClient;
  final CaPinMutex mutex;

  Future<void> fetchAndPin({
    required String instanceId,
    required String host,
    required Future<bool> Function() isCurrentAttemptStillLive,
  }) async {
    final existing = await pinStore.read(deploymentId: instanceId);
    if (existing != null) return;

    try {
      final result = await sshCommandRunner.run(
        instanceId: instanceId,
        host: host,
        command: RootSshCommand.exportCaddyCaFingerprint,
      );
      if (result.exitCode != 0) {
        throw Exception(result.stderr.isEmpty
            ? 'export-caddy-ca-fingerprint failed'
            : result.stderr);
      }
      final pin = CaddyCaPin.fromExportJson(
        jsonDecode(result.stdout) as Map<String, dynamic>,
      );

      await mutex.synchronized(() async {
        if (!await isCurrentAttemptStillLive()) return;
        if (await pinStore.read(deploymentId: instanceId) != null) return;
        await pinStore.write(deploymentId: instanceId, pin: pin);
        pinningHttpClient.updatePin(pin.certificatePem);
      });
    } on Object catch (error, stackTrace) {
      await pocketCoderDiagnosticCapture.capture(
        error: error,
        stackTrace: stackTrace,
        source: 'CaPinFetcher',
        operation: 'fetchAndPin',
        errorCode: 'DEPLOY_CADDY_CA_PIN_FAILED',
      );
    }
  }
}
