import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:pocketcoder_flutter/domain/deployment/readiness_phase.dart';
import 'package:pocketcoder_flutter/domain/deployment/readiness_update.dart';
import 'package:pocketcoder_flutter/domain/deployment/server_status_document.dart';

class DeploymentReadinessMonitor {
  DeploymentReadinessMonitor({required http.Client client, DateTime Function()? now})
    : _client = client,
      _now = now ?? DateTime.now;

  final http.Client _client;
  final DateTime Function() _now;

  Stream<ReadinessUpdate> monitor({required String hostname}) async* {
    final started = _now();
    var adoptedRunId = '';
    var fallback = false;
    var lastPhase = ReadinessPhase.waitingForCaddy;
    ServerStatusDocument? lastStatusDocument;
    var lastStatusTransportAuthenticated = false;
    var firstPoll = true;
    var pollingAttempt = 0;

    while (_now().difference(started) < const Duration(minutes: 30)) {
      pollingAttempt += 1;
      var emittedThisAttempt = false;
      if (!fallback) {
        http.Response? statusResponse;
        var statusTransportAuthenticated = false;
        try {
          statusResponse = await _client.get(Uri.https(hostname, '/_pocketcoder/status.json'));
          statusTransportAuthenticated = true;
        } on HandshakeException {
          try {
            statusResponse = await _client.get(Uri.http(hostname, '/_pocketcoder/status.json'));
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
            lastStatusDocument = doc;
            lastStatusTransportAuthenticated = statusTransportAuthenticated;
            if (adoptedRunId.isEmpty || adoptedRunId != doc.runId) {
              adoptedRunId = doc.runId;
            }
            final phase = ReadinessPhaseX.fromWireName(doc.phase);
            if (phase.index >= lastPhase.index) {
              lastPhase = phase;
            }
            yield ReadinessUpdate(
              phase: lastPhase,
              pollingAttempt: pollingAttempt,
              statusTransportAuthenticated: statusTransportAuthenticated,
              statusDocument: doc,
            );
            emittedThisAttempt = true;
            if (doc.error != null && doc.runId == adoptedRunId) {
              yield ReadinessUpdate(
                phase: ReadinessPhase.failed,
                pollingAttempt: pollingAttempt,
                statusTransportAuthenticated: statusTransportAuthenticated,
                statusDocument: doc,
              );
              return;
            }
          }
        }
      }

      try {
        final health = await _client.get(Uri.https(hostname, '/api/health'));
        if (health.statusCode == 200) {
          yield ReadinessUpdate(
            phase: ReadinessPhase.ready,
            pollingAttempt: pollingAttempt,
            statusTransportAuthenticated: lastStatusTransportAuthenticated,
            statusDocument: lastStatusDocument,
          );
          return;
        }
      } on Object {
        // The next status poll or the budget will decide the terminal state.
      }

      if (!emittedThisAttempt) {
        yield ReadinessUpdate(
          phase: lastPhase,
          pollingAttempt: pollingAttempt,
          statusTransportAuthenticated: false,
          statusDocument: lastStatusDocument,
        );
      }

      if (!firstPoll) {
        await Future<void>.delayed(const Duration(seconds: 3));
      }
      firstPoll = false;
    }
    yield ReadinessUpdate(
      phase: ReadinessPhase.timedOut,
      pollingAttempt: pollingAttempt,
      statusTransportAuthenticated: false,
      statusDocument: lastStatusDocument,
    );
  }
}
