import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketcoder_pro/domain/deployment/deployment_phase.dart';
import 'package:pocketcoder_pro/domain/deployment/server_status_document.dart';
import 'package:pocketcoder_pro/infrastructure/deployment/deployment_readiness_service.dart';

class _QueueClient extends http.BaseClient {
  _QueueClient(this._responses);

  final List<http.Response> _responses;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_responses.isEmpty) {
      return http.StreamedResponse(const Stream.empty(), 503);
    }
    final response = _responses.removeAt(0);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

http.Response status(
  String phase, {
  String? detail,
  String? error,
  String runId = 'run-1',
}) =>
    http.Response(
      jsonEncode({
        'schema': 1,
        'runId': runId,
        'phase': phase,
        'updatedAt': '2026-08-08T18:00:00Z',
        'sourceCommit': 'abc',
        'detail': detail,
        'error': error,
        'futureField': {'kept': true},
      }),
      200,
    );

void main() {
  test('parses the real NixOS and Standard Linux status shape', () {
    final document = ServerStatusDocument.tryParse(
      status('fetching_release', detail: 'cloning_source').body,
    );
    expect(document?.phase, 'fetching_release');
    expect(document?.detail, 'cloning_source');
    expect(document?.sourceCommit, 'abc');
    expect(document?.raw['futureField'], {'kept': true});
    expect(
      ServerStatusDocument.tryParse(
        '{"schema_version":1,"run_id":"old","phase":"fetching_release","heartbeat_at":"2026-08-08T18:00:00Z"}',
      ),
      isNull,
    );
  });

  test('unknown wire phases remain working and health grants ready', () async {
    final service = DeploymentReadinessService(
      client: _QueueClient([
        status('future_phase'),
        http.Response('', 200),
      ]),
    );
    final updates = await service
        .monitor(hostname: 'example.test', instanceId: 'i')
        .toList();
    expect(updates.map((update) => update.phase), [
      DeploymentPhase.waitingForCaddy,
      DeploymentPhase.ready,
    ]);
    expect(updates.map((update) => update.pollingAttempt), [1, 1]);
    expect(updates.last.statusDocument?.phase, 'future_phase');
  });

  test('status errors yield failed and terminate immediately', () async {
    final service = DeploymentReadinessService(
      client: _QueueClient([status('compose_up', error: 'bootstrap_failed')]),
    );
    final updates = await service
        .monitor(hostname: 'example.test', instanceId: 'i')
        .toList();
    expect(updates.map((update) => update.phase), [
      DeploymentPhase.composeUp,
      DeploymentPhase.failed,
    ]);
    expect(updates.last.statusDocument?.error, 'bootstrap_failed');
  });

  test('a 404 switches to health-only fallback', () async {
    final service = DeploymentReadinessService(
      client: _QueueClient([
        http.Response('', 404),
        http.Response('', 200),
      ]),
    );
    final updates = await service
        .monitor(hostname: 'example.test', instanceId: 'i')
        .toList();
    expect(updates.map((update) => update.phase), [DeploymentPhase.ready]);
    expect(updates.single.pollingAttempt, 1);
  });

  test('increments polling attempts when endpoints are not ready', () async {
    final service = DeploymentReadinessService(
      client: _QueueClient([
        http.Response('', 503),
        http.Response('', 503),
        status('compose_up'),
        http.Response('', 200),
      ]),
    );

    final updates = await service
        .monitor(hostname: 'example.test', instanceId: 'i')
        .toList();

    expect(updates.map((update) => update.pollingAttempt), [1, 2, 2]);
    expect(updates.map((update) => update.phase), [
      DeploymentPhase.waitingForCaddy,
      DeploymentPhase.composeUp,
      DeploymentPhase.ready,
    ]);
  });
}
