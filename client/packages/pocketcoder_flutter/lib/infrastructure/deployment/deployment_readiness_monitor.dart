import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:pocketcoder_flutter/domain/deployment/deploy_operation_key.dart';
import 'package:pocketcoder_flutter/domain/deployment/readiness_update.dart';
import 'package:pocketcoder_flutter/domain/deployment/server_status_document.dart';

class DeploymentReadinessMonitor {
  DeploymentReadinessMonitor({
    required http.Client client,
    DateTime Function()? now,
    Duration pollInterval = const Duration(seconds: 3),
  }) : _client = client,
       _now = now ?? DateTime.now,
       _pollInterval = pollInterval;

  final http.Client _client;
  final DateTime Function() _now;
  final Duration _pollInterval;

  Stream<ReadinessUpdate> monitor({required String hostname}) async* {
    final started = _now();
    var adoptedRunId = '';
    var fallback = false;
    var currentKey = DeployOperationKey.waitingForConnection;
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
            // No monotonic clamp: mirror whatever the server reports,
            // including a real retry-driven regression to an earlier key.
            // Hold the previous key rather than falling back to a default
            // when the wire value is unparseable (e.g. a newer server
            // reporting a phase this client predates).
            final parsedKey = DeployOperationKeyX.fromWireName(doc.operation);
            if (parsedKey != null) {
              currentKey = parsedKey;
            }
            yield ReadinessUpdate(
              operationKey: currentKey,
              pollingAttempt: pollingAttempt,
              statusTransportAuthenticated: statusTransportAuthenticated,
              statusDocument: doc,
            );
            emittedThisAttempt = true;
            final isTerminalError = doc.errorCode != null && doc.attempt >= doc.maxAttempts;
            if (isTerminalError) {
              return;
            }
            // A transient error (attempt < maxAttempts) already got its
            // operation-key update above; the stream simply keeps polling.
          }
        }
      }

      try {
        final health = await _client.get(Uri.https(hostname, '/api/health'));
        if (health.statusCode == 200) {
          yield ReadinessUpdate(
            operationKey: DeployOperationKey.ready,
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
          operationKey: currentKey,
          pollingAttempt: pollingAttempt,
          statusTransportAuthenticated: false,
          statusDocument: lastStatusDocument,
        );
      }

      if (!firstPoll) {
        await Future<void>.delayed(_pollInterval);
      }
      firstPoll = false;
    }
    // Budget exhausted with no ready/terminal-error outcome. This does not
    // introduce a new "timedOut" key -- DeployOperationKey has none, by
    // design (see spec: readiness timeout is a Pro-level terminal outcome,
    // not a server-reported operation). Pro's consumer applies its own
    // 30-minute-elapsed-with-no-terminal-update rule; this stream simply
    // ends.
  }
}
