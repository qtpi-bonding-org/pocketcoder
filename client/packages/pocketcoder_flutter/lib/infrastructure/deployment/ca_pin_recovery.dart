import 'package:pocketcoder_flutter/infrastructure/core/logger.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/ca_pin_fetcher.dart';

/// Narrow lookup for "what deployment is the app currently talking to."
/// Kept separate from any concrete deployment-tracking implementation so
/// this package never depends on app-specific deployment state (see
/// CaPinWriter for the same narrow-interface pattern) -- each app target
/// supplies its own implementation.
abstract class CurrentDeploymentLookup {
  ({String instanceId, String host})? get current;
}

/// Recovers from a certificate-validation failure against the currently
/// pinned CA by re-fetching it over SSH. Deliberately conservative: this
/// only exists to repair a pin that was correct once and has since gone
/// stale (a redeployed/reprovisioned box minted a new self-signed CA) --
/// it must never fire for a handshake failure that has nothing to do with
/// the pinned deployment at all (a captive portal, a corporate
/// TLS-intercepting proxy hit while calling Linode OAuth or a relay), and
/// must never hammer the box with an SSH attempt per failed request.
class CaPinRecovery {
  CaPinRecovery({
    required this.caPinFetcher,
    required this.currentDeployment,
    this.cooldown = const Duration(seconds: 60),
  });

  final CaPinFetcher caPinFetcher;
  final CurrentDeploymentLookup currentDeployment;
  final Duration cooldown;

  DateTime? _lastAttempt;

  /// Returns true only if a fresh pin was fetched AND it actually differs
  /// from what was previously trusted -- only then is retrying the
  /// original request worthwhile. `false` means either recovery didn't
  /// apply here at all, or the pin wasn't actually the problem.
  Future<bool> recoverIfStale({required Uri requestUrl}) async {
    final deployment = currentDeployment.current;
    AppLogger.debug('CaPinRecovery.recoverIfStale called', {
      'requestUrl': requestUrl.toString(),
      'requestHost': requestUrl.host,
      'currentDeployment': deployment == null
          ? null
          : {'instanceId': deployment.instanceId, 'host': deployment.host},
    });
    if (deployment == null) {
      AppLogger.debug(
          'CaPinRecovery.recoverIfStale: no current deployment -- bail');
      return false;
    }

    // Only ever re-pin for the deployment's own host. A cert failure
    // against Linode OAuth, the OAuth relay, or the image relay -- e.g. a
    // captive portal or corporate TLS-intercepting proxy -- must never
    // trigger an SSH attempt into the user's own VPS.
    if (requestUrl.host != deployment.host) {
      AppLogger.debug('CaPinRecovery.recoverIfStale: host mismatch -- bail', {
        'requestHost': requestUrl.host,
        'deploymentHost': deployment.host,
      });
      return false;
    }

    // Recovery repairs a pin that already existed and went stale. A
    // deployment with no pin at all yet is fetchAndPin's job (run once
    // from DeploymentReadinessPollOperation), not recovery's.
    final existing =
        await caPinFetcher.pinStore.read(deploymentId: deployment.instanceId);
    if (existing == null) {
      AppLogger.debug(
          'CaPinRecovery.recoverIfStale: no existing durable pin -- bail', {
        'instanceId': deployment.instanceId,
      });
      return false;
    }

    final now = DateTime.now();
    final lastAttempt = _lastAttempt;
    if (lastAttempt != null && now.difference(lastAttempt) < cooldown) {
      AppLogger.debug(
          'CaPinRecovery.recoverIfStale: still in cooldown -- bail', {
        'lastAttempt': lastAttempt.toIso8601String(),
        'sinceLastAttempt': now.difference(lastAttempt).toString(),
        'cooldown': cooldown.toString(),
      });
      return false;
    }
    _lastAttempt = now;

    AppLogger.debug('CaPinRecovery.recoverIfStale: forcing SSH refetch', {
      'instanceId': deployment.instanceId,
      'host': deployment.host,
    });
    final refetched = await caPinFetcher.forceRefetch(
      instanceId: deployment.instanceId,
      host: deployment.host,
    );
    AppLogger.debug('CaPinRecovery.recoverIfStale: forceRefetch result', {
      'instanceId': deployment.instanceId,
      'refetched': refetched,
    });
    return refetched;
  }

  /// [currentDeployment] may still be completing its own async load at
  /// boot, so a null read is polled rather than treated as final; bounded by
  /// [timeout] since there may genuinely be no deployment yet.
  Future<void> warmUp({Duration timeout = const Duration(seconds: 5)}) async {
    final deadline = DateTime.now().add(timeout);
    var deployment = currentDeployment.current;
    while (deployment == null && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      deployment = currentDeployment.current;
    }
    if (deployment == null) {
      AppLogger.debug(
          'CaPinRecovery.warmUp: no deployment available before timeout -- skipping');
      return;
    }
    AppLogger.debug('CaPinRecovery.warmUp: fetching/pinning cached CA', {
      'instanceId': deployment.instanceId,
      'host': deployment.host,
    });
    await caPinFetcher.fetchAndPin(
      instanceId: deployment.instanceId,
      host: deployment.host,
      isCurrentAttemptStillLive: () async => true,
    );
  }
}
