import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:pocketcoder_pro/domain/deployment/deployment_phase.dart';
import 'package:pocketcoder_pro/domain/deployment/server_status_document.dart';

class DeploymentReadinessService {
  DeploymentReadinessService({
    required http.Client client,
    DateTime Function()? now,
  })  : _client = client,
        _now = now ?? DateTime.now;

  final http.Client _client;
  final DateTime Function() _now;

  Stream<DeploymentPhase> monitor({
    required String hostname,
    required String instanceId,
  }) async* {
    final started = _now();
    var adoptedRunId = '';
    var fallback = false;
    var lastPhase = DeploymentPhase.waitingForCaddy;
    var firstPoll = true;

    while (_now().difference(started) < const Duration(minutes: 30)) {
      if (!fallback) {
        http.Response? statusResponse;
        try {
          statusResponse = await _client.get(Uri.https(
            hostname,
            '/_pocketcoder/status.json',
          ));
        } on HandshakeException {
          try {
            statusResponse = await _client.get(Uri.http(
              hostname,
              '/_pocketcoder/status.json',
            ));
          } on Object {
            statusResponse = null;
          }
        } on SocketException {
          statusResponse = null;
        } on Object {
          statusResponse = null;
        }

        if (statusResponse?.statusCode == 404) {
          fallback = true;
        } else if (statusResponse?.statusCode == 200) {
          final doc = ServerStatusDocument.tryParse(statusResponse?.body ?? '');
          if (doc != null) {
            if (adoptedRunId.isEmpty || adoptedRunId != doc.runId) {
              adoptedRunId = doc.runId;
            }
            final phase = DeploymentPhaseX.fromWireName(doc.phase);
            if (phase.index >= lastPhase.index) {
              lastPhase = phase;
              yield phase;
            }
            if (doc.error != null && doc.runId == adoptedRunId) {
              yield DeploymentPhase.failed;
            }
          }
        }
      }

      try {
        final health = await _client.get(Uri.https(hostname, '/api/health'));
        if (health.statusCode == 200) {
          yield DeploymentPhase.ready;
          return;
        }
      } on Object {
        // The next status poll or the budget will decide the terminal state.
      }

      if (!firstPoll) {
        await Future<void>.delayed(const Duration(seconds: 3));
      }
      firstPoll = false;
    }
    yield DeploymentPhase.timedOut;
  }
}
