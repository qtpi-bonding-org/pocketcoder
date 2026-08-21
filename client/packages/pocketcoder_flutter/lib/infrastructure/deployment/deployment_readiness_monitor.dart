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
    void Function(String message)? onLog,
    bool printLogs = true,
  }) : _client = client,
       _now = now ?? DateTime.now,
       _pollInterval = pollInterval,
       _onLog = onLog,
       _printLogs = printLogs;

  final http.Client _client;
  final DateTime Function() _now;
  final Duration _pollInterval;
  final void Function(String message)? _onLog;
  final bool _printLogs;

  // This stage was previously silent by design (no print/debugPrint at
  // all), unlike the verbose provisioning steps before it -- which made a
  // real stall indistinguishable from normal quiet polling from the log
  // alone. Mirrors LinodeBootTimeInstaller's _log pattern (elapsed-time
  // prefix, print gated by _printLogs, optional _onLog hook).
  void _log(Stopwatch sw, String message) {
    final line = 'DeploymentReadinessMonitor [+${sw.elapsed.inSeconds}s]: $message';
    if (_printLogs) {
      // ignore: avoid_print
      print(line);
    }
    _onLog?.call(line);
  }

  Stream<ReadinessUpdate> monitor({required String hostname}) async* {
    final sw = Stopwatch()..start();
    final started = _now();
    var adoptedRunId = '';
    var fallback = false;
    var currentKey = DeployOperationKey.waitingForConnection;
    ServerStatusDocument? lastStatusDocument;
    var lastStatusTransportAuthenticated = false;
    var firstPoll = true;
    var pollingAttempt = 0;

    _log(sw, 'monitor started for $hostname');

    while (_now().difference(started) < const Duration(minutes: 30)) {
      pollingAttempt += 1;
      var emittedThisAttempt = false;
      if (!fallback) {
        http.Response? statusResponse;
        var statusTransportAuthenticated = false;
        try {
          statusResponse = await _client.get(Uri.https(hostname, '/_pocketcoder/status.json'));
          statusTransportAuthenticated = true;
        } on HandshakeException catch (error) {
          _log(sw, 'status-poll $pollingAttempt: HTTPS handshake failed ($error), falling back to HTTP');
          try {
            statusResponse = await _client.get(Uri.http(hostname, '/_pocketcoder/status.json'));
          } on Object catch (fallbackError) {
            _log(sw, 'status-poll $pollingAttempt: HTTP fallback also failed: $fallbackError');
            statusResponse = null;
          }
        } on SocketException catch (error) {
          _log(sw, 'status-poll $pollingAttempt: HTTPS socket error (server not reachable yet?): $error');
          statusResponse = null;
        } on Object catch (error) {
          _log(sw, 'status-poll $pollingAttempt: HTTPS request threw ${error.runtimeType}: $error');
          statusResponse = null;
        }

        if (statusResponse?.statusCode == 404) {
          _log(sw, 'status-poll $pollingAttempt: status.json 404 -- switching to health-only fallback mode');
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
            } else {
              _log(sw, 'status-poll $pollingAttempt: server operation "${doc.operation}" not recognized by this client -- holding at $currentKey');
            }
            _log(sw, 'status-poll $pollingAttempt: operation=${doc.operation} errorCode=${doc.errorCode} attempt=${doc.attempt}/${doc.maxAttempts}');
            yield ReadinessUpdate(
              operationKey: currentKey,
              pollingAttempt: pollingAttempt,
              statusTransportAuthenticated: statusTransportAuthenticated,
              statusDocument: doc,
            );
            emittedThisAttempt = true;
            final isTerminalError = doc.errorCode != null && doc.attempt >= doc.maxAttempts;
            if (isTerminalError) {
              _log(sw, 'status-poll $pollingAttempt: terminal error ${doc.errorCode} -- ending monitor');
              return;
            }
            // A transient error (attempt < maxAttempts) already got its
            // operation-key update above; the stream simply keeps polling.
          } else {
            // A 200 with a body this client can't parse is invisible
            // without this log -- e.g. a server schema whose top-level
            // key names (operation/errorCode) don't match what this
            // client's ServerStatusDocument.tryParse expects. The status
            // is silently dropped and the UI never advances, with no
            // other signal that anything went wrong.
            _log(sw, 'status-poll $pollingAttempt: status.json returned 200 but failed to parse -- raw body: ${statusResponse?.body}');
          }
        } else if (statusResponse != null) {
          _log(sw, 'status-poll $pollingAttempt: status.json returned HTTP ${statusResponse.statusCode}');
        }
      }

      try {
        final health = await _client.get(Uri.https(hostname, '/api/health'));
        if (health.statusCode == 200) {
          _log(sw, 'health-poll $pollingAttempt: /api/health 200 -- ready');
          yield ReadinessUpdate(
            operationKey: DeployOperationKey.ready,
            pollingAttempt: pollingAttempt,
            statusTransportAuthenticated: lastStatusTransportAuthenticated,
            statusDocument: lastStatusDocument,
          );
          return;
        } else {
          _log(sw, 'health-poll $pollingAttempt: /api/health returned HTTP ${health.statusCode}');
        }
      } on Object catch (error) {
        _log(sw, 'health-poll $pollingAttempt: /api/health threw ${error.runtimeType}: $error');
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
    _log(sw, '30-minute polling budget exhausted with no ready/terminal outcome');
  }
}
