import 'package:flutter_aeroform/domain/deployment/cancellation_token.dart';
import 'package:flutter_aeroform/domain/deployment/context_key.dart';
import 'package:flutter_aeroform/domain/deployment/idempotent_operation.dart';
import 'package:flutter_aeroform/domain/deployment/recovery_outcome.dart';
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';
import 'package:pocketcoder_flutter/domain/deployment/deploy_context_keys.dart';
import 'package:pocketcoder_flutter/domain/deployment/deploy_operation_key.dart';
import 'package:pocketcoder_flutter/domain/deployment/readiness_update.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/ca_pin_fetcher.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/ssh_host_identity_capture.dart';

final deployReadyKey = ContextKey<bool>(
  'deploy.ready',
  (v) => v,
  (j) => j as bool,
);

/// The deploy track's one long-running readiness operation.
class DeploymentReadinessPollOperation extends IdempotentOperation<bool> {
  DeploymentReadinessPollOperation({
    required this.readinessSource,
    required this.secureStorage,
    required this.caPinFetcher,
    required this.isCurrentAttemptStillLive,
  });

  final Stream<ReadinessUpdate> Function({required String hostname})
      readinessSource;
  final ISecureStorage secureStorage;
  final CaPinFetcher caPinFetcher;
  final Future<bool> Function() isCurrentAttemptStillLive;

  @override
  String get key => 'deploy_readiness_poll';

  @override
  ContextKey<bool> get resultKey => deployReadyKey;

  @override
  Future<bool> run(OperationContext context, CancellationToken cancel) async {
    final instance = context.get(instanceContextKey);
    ReadinessUpdate? lastUpdate;

    // Must be the sslip.io hostname, not the bare IP: Caddy serves a
    // *third*, separate site block for the bare-IP host that only ever
    // presents the self-signed internal-CA certificate (no ACME issuer at
    // all), which an unpinned client here can never trust -- confirmed
    // live, this made /api/health readiness checks fail forever (no HTTP
    // fallback exists for that endpoint, unlike status.json's), hanging
    // every real deployment's readiness poll indefinitely even once the
    // box was fully healthy. The sslip.io hostname's site block obtains a
    // real ACME certificate (falling back to the same self-signed cert
    // only if ACME itself is unavailable, e.g. rate-limited) and is what
    // every other readiness-adjacent check in this codebase already uses.
    final hostname = '${instance.ipAddress.replaceAll('.', '-')}.sslip.io';

    await for (final update in readinessSource(hostname: hostname)) {
      if (cancel.isRequested) {
        throw StateError('cancelled while waiting for deploy readiness');
      }
      lastUpdate = update;

      await captureSshHostIdentity(
        secureStorage: secureStorage,
        instanceId: instance.id,
        update: update,
      );
      if (cancel.isRequested) {
        throw StateError('cancelled while waiting for deploy readiness');
      }

      // Deliberately not awaited: pinning must not delay readiness polling.
      caPinFetcher.fetchAndPin(
        instanceId: instance.id,
        host: instance.ipAddress,
        isCurrentAttemptStillLive: isCurrentAttemptStillLive,
      );

      if (update.operationKey == DeployOperationKey.ready) return true;
    }

    if (lastUpdate?.isTerminalError ?? false) {
      throw StateError(
        'deploy readiness terminal error: '
        '${lastUpdate?.statusDocument?.errorCode}',
      );
    }
    throw Exception(
      'deploy readiness monitor ended with no ready/terminal outcome',
    );
  }

  @override
  Future<RecoveryOutcome<bool>> recover(
          OperationContext context, CancellationToken cancel) async =>
      Absent<bool>();
}
