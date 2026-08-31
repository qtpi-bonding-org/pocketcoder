import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// One decoded, generic SSE record (spec:
/// https://html.spec.whatwg.org/multipage/server-sent-events.html).
///
/// Consecutive `data:` fields are joined with `\n`. The newline which
/// terminates the record is not included. This deliberately generalizes the
/// single-line `data:` assumption made by the original AgentStreamClient.
typedef SseFrame = ({String? id, String? event, String data});

class SseHttpException implements Exception {
  const SseHttpException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'SSE stream returned HTTP $statusCode';
}

/// A small, protocol-agnostic SSE reader. It owns connection cancellation but
/// does not own (or close) the injected HTTP client and never retries.
class SseStreamClient {
  SseStreamClient({required http.Client httpClient}) : _http = httpClient;

  final http.Client _http;
  final Set<Future<void> Function()> _cancellers = {};

  /// Opens one SSE connection using the caller-supplied request.
  Stream<SseFrame> connect(http.BaseRequest Function() buildRequest) {
    final controller = StreamController<SseFrame>();
    StreamSubscription<String>? lineSub;
    var cancelled = false;

    // Removed once the connection actually terminates (done, error, setup
    // failure, or cancellation) -- NOT immediately after the async setup
    // body returns control, which for a long-lived stream happens right
    // after `.listen()` is installed, long before the connection's real
    // lifecycle ends. Removing it that early meant `cancel()` (which
    // iterates `_cancellers`) silently aborted nothing for any connection
    // already past setup.
    late void Function() forget;

    Future<void> cancelConnection() async {
      cancelled = true;
      await lineSub?.cancel();
      forget();
    }

    forget = () => _cancellers.remove(cancelConnection);

    controller.onCancel = cancelConnection;
    _cancellers.add(cancelConnection);

    Future<void>(() async {
      try {
        final response = await _http.send(buildRequest());
        if (cancelled) {
          await response.stream.listen(null).cancel();
          forget();
          return;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          await response.stream.drain<void>();
          throw SseHttpException(response.statusCode);
        }

        String? currentId;
        String? currentEvent;
        var dataLines = <String>[];

        void dispatch() {
          if (dataLines.isNotEmpty) {
            controller.add((
              id: currentId,
              event: currentEvent,
              data: dataLines.join('\n'),
            ));
          }
          // Fields belong to this record, including records containing only
          // comments or metadata and therefore emitting no frame.
          currentId = null;
          currentEvent = null;
          dataLines = <String>[];
        }

        lineSub = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
          (line) {
            if (cancelled) return;
            if (line.isEmpty) {
              dispatch();
              return;
            }
            if (line.startsWith(':')) return;
            final colon = line.indexOf(':');
            final field = colon < 0 ? line : line.substring(0, colon);
            var value = colon < 0 ? '' : line.substring(colon + 1);
            if (value.startsWith(' ')) value = value.substring(1);
            switch (field) {
              case 'id':
                currentId = value;
              case 'event':
                currentEvent = value;
              case 'data':
                dataLines.add(value);
              case 'retry':
                break;
              default:
                break;
            }
          },
          onError: (Object e, StackTrace st) {
            controller.addError(e, st);
            controller.close();
            forget();
          },
          onDone: () {
            dispatch();
            controller.close();
            forget();
          },
          cancelOnError: false,
        );

        if (cancelled) {
          await lineSub?.cancel();
          forget();
        }
      } catch (e, st) {
        if (!cancelled) {
          controller.addError(e, st);
          await controller.close();
        }
        forget();
      }
    });

    return controller.stream;
  }

  /// Aborts all connections owned by this instance without closing [_http].
  /// Snapshots the current cancellers first: each one removes itself (via
  /// `forget()` above) once it finishes, which would otherwise mutate
  /// `_cancellers` while this method is still iterating it.
  Future<void> cancel() async {
    await Future.wait(_cancellers.toList().map((cancel) => cancel()));
  }
}
