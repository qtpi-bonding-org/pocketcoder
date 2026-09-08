import 'dart:convert';

import 'package:pocketcoder_flutter/domain/deployment/caddy_ca_pin.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_command_runner.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';
import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';
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
    if (existing != null) {
      pinningHttpClient.updatePin(existing.certificatePem);
      return;
    }
    await _sshFetchAndStore(
      instanceId: instanceId,
      host: host,
      isCurrentAttemptStillLive: isCurrentAttemptStillLive,
      skipIfAlreadyStored: true,
    );
  }

  /// Unlike [fetchAndPin], always re-fetches over SSH regardless of what's
  /// already stored -- used by CaPinRecovery when a request has just
  /// failed cert validation against the currently-pinned CA, so the
  /// existing (now-suspect) pin must never short-circuit the fetch.
  ///
  /// Returns whether the freshly-fetched CA actually differs from what was
  /// stored. A caller retrying a failed request on the strength of this
  /// recovery should treat `false` as "the pin wasn't the problem" --
  /// retrying again would just double the latency of a failure that has
  /// some other cause.
  Future<bool> forceRefetch({
    required String instanceId,
    required String host,
  }) async {
    final existing = await pinStore.read(deploymentId: instanceId);
    final fetched = await _sshFetchAndStore(
      instanceId: instanceId,
      host: host,
      isCurrentAttemptStillLive: () async => true,
      skipIfAlreadyStored: false,
    );
    return fetched != null && fetched.fingerprint != existing?.fingerprint;
  }

  Future<CaddyCaPin?> _sshFetchAndStore({
    required String instanceId,
    required String host,
    required Future<bool> Function() isCurrentAttemptStillLive,
    required bool skipIfAlreadyStored,
  }) async {
    AppLogger.debug('CaPinFetcher._sshFetchAndStore start', {
      'instanceId': instanceId,
      'host': host,
      'skipIfAlreadyStored': skipIfAlreadyStored,
    });
    try {
      final result = await sshCommandRunner.run(
        instanceId: instanceId,
        host: host,
        command: RootSshCommand.exportCaddyCaFingerprint,
      );
      AppLogger.debug('CaPinFetcher._sshFetchAndStore ssh result', {
        'instanceId': instanceId,
        'host': host,
        'exitCode': result.exitCode,
        'stderr': result.stderr,
        'stdoutLength': result.stdout.length,
      });
      if (result.exitCode != 0) {
        throw Exception(result.stderr.isEmpty
            ? 'export-caddy-ca-fingerprint failed'
            : result.stderr);
      }
      final pin = CaddyCaPin.fromExportJson(
        jsonDecode(result.stdout) as Map<String, dynamic>,
      );

      return await mutex.synchronized(() async {
        if (!await isCurrentAttemptStillLive()) {
          AppLogger.debug(
              'CaPinFetcher._sshFetchAndStore: attempt no longer live -- discarding fetched pin',
              {'instanceId': instanceId});
          return null;
        }
        if (skipIfAlreadyStored &&
            await pinStore.read(deploymentId: instanceId) != null) {
          AppLogger.debug(
              'CaPinFetcher._sshFetchAndStore: already stored, skipping write',
              {'instanceId': instanceId});
          return null;
        }
        await pinStore.write(deploymentId: instanceId, pin: pin);
        pinningHttpClient.updatePin(pin.certificatePem);
        AppLogger.debug(
            'CaPinFetcher._sshFetchAndStore: wrote pin and updated live client',
            {'instanceId': instanceId, 'fingerprint': pin.fingerprint});
        return pin;
      });
    } on Object catch (error, stackTrace) {
      AppLogger.warning('CaPinFetcher._sshFetchAndStore failed', {
        'instanceId': instanceId,
        'host': host,
        'skipIfAlreadyStored': skipIfAlreadyStored,
        'errorType': error.runtimeType.toString(),
        'error': error.toString(),
      });
      await pocketCoderDiagnosticCapture.capture(
        error: error,
        stackTrace: stackTrace,
        source: 'CaPinFetcher',
        operation: skipIfAlreadyStored ? 'fetchAndPin' : 'forceRefetch',
        errorCode: 'DEPLOY_CADDY_CA_PIN_FAILED',
      );
      return null;
    }
  }
}
