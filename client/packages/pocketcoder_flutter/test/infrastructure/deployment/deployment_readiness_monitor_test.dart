import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketcoder_flutter/domain/deployment/readiness_phase.dart';
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
          '{"schema":2,"runId":"r1","phase":"ready","updatedAt":"2026-08-16T00:00:00Z"}',
          200,
        );
      }
      if (request.url.path.contains('/api/health')) {
        return http.Response('ok', 200);
      }
      return http.Response('not found', 404);
    });

    final monitor = DeploymentReadinessMonitor(client: client);
    final updates = await monitor.monitor(hostname: 'example.com').take(2).toList();

    expect(httpsCalls, greaterThan(0));
    expect(updates.last.phase, ReadinessPhase.ready);
  });
}
