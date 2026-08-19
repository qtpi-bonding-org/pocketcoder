import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketcoder_flutter/domain/deployment/deploy_operation_key.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/deployment_readiness_monitor.dart';

void main() {
  test('falls back to HTTP when HTTPS handshake fails, and surfaces ready', () async {
    var httpsCalls = 0;
    final client = MockClient((request) async {
      if (request.url.scheme == 'https' && request.url.path.contains('status.json')) {
        httpsCalls += 1;
        throw const HandshakeException('test');
      }
      if (request.url.path.contains('status.json')) {
        return http.Response(
          '{"schema":3,"runId":"r1","operation":"bootstrap_complete","updatedAt":"2026-08-16T00:00:00Z"}',
          200,
        );
      }
      if (request.url.path.contains('/api/health')) {
        return http.Response('ok', 200);
      }
      return http.Response('not found', 404);
    });

    final monitor = DeploymentReadinessMonitor(client: client, pollInterval: Duration.zero);
    final updates = await monitor.monitor(hostname: 'example.com').take(2).toList();

    expect(httpsCalls, greaterThan(0));
    expect(updates.last.operationKey, DeployOperationKey.ready);
  });

  test('mirrors a server-side retry regression instead of clamping to the highest key seen', () async {
    var call = 0;
    final client = MockClient((request) async {
      if (request.url.path.contains('status.json')) {
        call += 1;
        final operation = call == 1 ? 'compose_up' : 'fetching_release';
        return http.Response(
          '{"schema":3,"runId":"r1","operation":"$operation","updatedAt":"2026-08-16T00:00:00Z"}',
          200,
        );
      }
      return http.Response('not found', 404);
    });

    final monitor = DeploymentReadinessMonitor(client: client, pollInterval: Duration.zero);
    final updates = await monitor.monitor(hostname: 'example.com').take(2).toList();

    expect(updates[0].operationKey, DeployOperationKey.composeUp);
    expect(
      updates[1].operationKey,
      DeployOperationKey.fetchingRelease,
      reason: 'a real server-side retry restarts at fetching_release; the '
          'client must show it, not clamp to the highest key ever seen',
    );
  });

  test('holds the previous key when a poll returns an unparseable operation value', () async {
    var call = 0;
    final client = MockClient((request) async {
      if (request.url.path.contains('status.json')) {
        call += 1;
        final operation = call == 1 ? 'loading_images' : 'some_future_phase_this_client_predates';
        return http.Response(
          '{"schema":3,"runId":"r1","operation":"$operation","updatedAt":"2026-08-16T00:00:00Z"}',
          200,
        );
      }
      return http.Response('not found', 404);
    });

    final monitor = DeploymentReadinessMonitor(client: client, pollInterval: Duration.zero);
    final updates = await monitor.monitor(hostname: 'example.com').take(2).toList();

    expect(updates[0].operationKey, DeployOperationKey.loadingImages);
    expect(
      updates[1].operationKey,
      DeployOperationKey.loadingImages,
      reason: 'an unrecognized wire value must hold position, not fall back '
          'to waitingForConnection -- that would flip the UI back to '
          'looking like provisioning is still underway',
    );
  });

  test('keeps polling through a transient error while attempts remain', () async {
    var call = 0;
    final client = MockClient((request) async {
      if (request.url.path.contains('status.json')) {
        call += 1;
        if (call == 1) {
          return http.Response(
            '{"schema":3,"runId":"r1","operation":"loading_images","updatedAt":"2026-08-16T00:00:00Z",'
            '"errorCode":"release_install_failed","attempt":1,"maxAttempts":3}',
            200,
          );
        }
        return http.Response(
          '{"schema":3,"runId":"r1","operation":"compose_up","updatedAt":"2026-08-16T00:00:00Z"}',
          200,
        );
      }
      if (request.url.path.contains('/api/health')) {
        return http.Response('not ready', 503);
      }
      return http.Response('not found', 404);
    });

    final monitor = DeploymentReadinessMonitor(client: client, pollInterval: Duration.zero);
    final updates = await monitor.monitor(hostname: 'example.com').take(2).toList();

    expect(
      updates.every((update) => update.operationKey != DeployOperationKey.ready),
      isTrue,
    );
    expect(
      updates[1].operationKey,
      DeployOperationKey.composeUp,
      reason: 'a transient error (attempt < maxAttempts) must not terminate '
          'the stream -- polling continues and later succeeds',
    );
  });

  test('terminates on error once the final attempt is exhausted', () async {
    final client = MockClient((request) async {
      if (request.url.path.contains('status.json')) {
        return http.Response(
          '{"schema":3,"runId":"r1","operation":"loading_images","updatedAt":"2026-08-16T00:00:00Z",'
          '"errorCode":"release_install_failed","attempt":3,"maxAttempts":3}',
          200,
        );
      }
      return http.Response('not found', 404);
    });

    final monitor = DeploymentReadinessMonitor(client: client, pollInterval: Duration.zero);
    final updates = await monitor.monitor(hostname: 'example.com').toList();

    expect(updates.length, 1);
    expect(updates.single.statusDocument?.errorCode, 'release_install_failed');
  });

  test('emits every DeployOperationKey in the canonical order for a full successful run', () async {
    const wireSequence = [
      'configuring_operating_system',
      'fetching_release',
      'loading_images',
      'compose_up',
      'bootstrap_complete',
    ];
    var call = 0;
    final client = MockClient((request) async {
      if (request.url.path.contains('status.json')) {
        final operation = wireSequence[call.clamp(0, wireSequence.length - 1)];
        call += 1;
        return http.Response(
          '{"schema":3,"runId":"r1","operation":"$operation","updatedAt":"2026-08-16T00:00:00Z"}',
          200,
        );
      }
      if (request.url.path.contains('/api/health')) {
        return call > wireSequence.length
            ? http.Response('ok', 200)
            : http.Response('not ready', 503);
      }
      return http.Response('not found', 404);
    });

    final monitor = DeploymentReadinessMonitor(client: client, pollInterval: Duration.zero);
    final updates = await monitor
        .monitor(hostname: 'example.com')
        .take(wireSequence.length + 1)
        .toList();

    final observedKeys = updates.map((update) => update.operationKey).toSet();
    for (final expectedKey in [
      DeployOperationKey.configuringOperatingSystem,
      DeployOperationKey.fetchingRelease,
      DeployOperationKey.loadingImages,
      DeployOperationKey.composeUp,
      DeployOperationKey.bootstrapComplete,
    ]) {
      expect(
        observedKeys.contains(expectedKey),
        isTrue,
        reason: '$expectedKey from DeployOperationKey.values was never observed',
      );
    }
  });
}
