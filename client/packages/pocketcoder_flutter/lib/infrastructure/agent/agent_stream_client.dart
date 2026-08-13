// Hand-rolled SSE client for the c1 agent stream. One [connect] call owns
// exactly one connection attempt — the returned [Stream] completes when the
// underlying byte stream ends or errors, and the caller (ChatCubit, future
// task) is responsible for reconnecting with a fresh cursor.
//
// We do NOT use `flutter_client_sse.SSEClient.subscribeToSSE` (plan Task 8
// blocker note): that package auto-retries after ~5s on error reusing the
// stale `?cursor=` baked into the first call, never completes the inner
// StreamController, and shares a global static client — silently defeating
// the caller-driven reconnect this protocol needs (spec §5.1). Hand-rolling
// the SSE read over [http.Client] is ~25 trivial lines and lets us own
// completion semantics + test with a fake [http.Client].
//
// Frame layout on the wire (SSE, one event per record; record = `id:` + `data:`
// lines, terminated by a blank line):
//
//   id: 3
//   data: {"type":"RUN_STARTED","threadId":"t","runId":"r"}
//   <blank>
//
// Comment/heartbeat lines start with `:` (e.g. `: ping`) and are dropped.
// `data:` is a single line (c1 newline-escapes any embedded newlines), so we
// accumulate one `id:` value + one `data:` value per frame.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agui_decode.dart';
import 'package:pocketcoder_flutter/infrastructure/core/api_endpoints.dart';

/// One decoded SSE frame: the hub-allocated seq (parsed from the `id:` line),
/// the verbatim `data:` JSON (carried through to the cache so it never gets
/// lossily re-encoded), and the typed AG-UI event from [decodeAguiFrame].
typedef StreamFrame = ({int seq, String rawJson, AguiEvent event});

/// Connects to `GET /api/pocketcoder/v1/chats/{chatId}/stream?cursor={cursor}` on
/// the injected PocketBase's [baseURL], authenticating with the injected
/// PocketBase's [authStore.token], and yields one [StreamFrame] per SSE
/// record. Reconnection is caller-driven: this class never retries
/// internally — the stream simply completes when the body ends or errors.
///
/// Construction is dependency-injected so tests can supply a fake
/// [http.Client] that produces a deterministic byte stream.
@lazySingleton
class AgentStreamClient {
  /// Reads `baseURL` and `authStore.token` off this instance. We never
  /// mutate the PocketBase — injection is for URL + token, nothing more.
  final PocketBase _pb;

  /// Owns the underlying HTTP I/O. Tests inject a fake whose `.send` returns
  /// a [http.StreamedResponse] over a synthetic byte stream.
  final http.Client _http;

  AgentStreamClient({
    required PocketBase pocketBase,
    required http.Client httpClient,
  })  : _pb = pocketBase,
        _http = httpClient;

  /// Opens one SSE connection and returns a single-subscription stream of
  /// decoded frames. The stream completes when the response body ends or
  /// errors; on either outcome the caller is expected to [connect] again
  /// with a fresh cursor (the chat's `maxSeq` after warm-up, or `0` for a
  /// cold open).
  ///
  /// Errors from [http.Client.send] are surfaced to the returned stream's
  /// `onError` listener — the caller decides whether to back off, retry
  /// with the same cursor, or surface the error. SSE-level parse failures
  /// (malformed JSON in a `data:` line) also surface as stream errors so a
  /// single bad frame does not silently truncate the stream.
  Stream<StreamFrame> connect(String chatId, {required int cursor}) {
    final controller = StreamController<StreamFrame>();
    StreamSubscription<String>? lineSub;

    // Run the async work out-of-band from the controller construction so
    // that returning the stream is synchronous (callers don't need to
    // await `.stream` resolution before listening).
    Future<void>(() async {
      try {
        final request = http.Request(
          'GET',
          Uri.parse(
            '${_pb.baseURL}${StreamingEndpoints.agentStream(chatId)}?cursor=$cursor',
          ),
        );
        // c1 only checks the raw token value, so we mirror what
        // PocketBase's own client does internally (see PocketBase.send
        // around `if (!headers.containsKey("Authorization") ...)`).
        request.headers['Authorization'] = _pb.authStore.token;

        final response = await _http.send(request);

        // Current frame accumulator. `id` may be null if the server omits
        // the `id:` line on a record (treated as seq 0 so the cache still
        // has something to key by — wrong but visible; the real c1 always
        // emits it).
        var currentId = 0;
        var haveId = false;
        var currentData = '';

        void dispatch() {
          if (currentData.isEmpty) {
            // Blank line without `data:` — SSE keep-alive; ignore.
            return;
          }
          try {
            final decoded = decodeAguiFrame(currentData);
            controller.add((
              seq: haveId ? currentId : 0,
              rawJson: decoded.rawJson,
              event: decoded.event,
            ));
          } catch (e, st) {
            controller.addError(e, st);
          }
          currentId = 0;
          haveId = false;
          currentData = '';
        }

        lineSub = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
          (line) {
            if (line.isEmpty) {
              // Record terminator.
              dispatch();
              return;
            }
            if (line.startsWith(':')) {
              // SSE comment / heartbeat — spec §5.2 lets the server emit
              // these to keep middleboxes alive.
              return;
            }
            // Field name is everything up to the first ':' per SSE spec;
            // value is everything after, with one optional leading space
            // stripped. We only care about `id` and `data`; everything else
            // (`event:`, `retry:`, etc.) is ignored for now.
            final colon = line.indexOf(':');
            final field = colon < 0 ? line : line.substring(0, colon);
            var value = colon < 0 ? '' : line.substring(colon + 1);
            if (value.startsWith(' ')) value = value.substring(1);
            switch (field) {
              case 'id':
                final parsed = int.tryParse(value);
                if (parsed != null) {
                  currentId = parsed;
                  haveId = true;
                }
              case 'data':
                currentData = value;
              default:
                // event:, retry:, etc. — not used by c1; ignored.
                break;
            }
          },
          onError: (Object e, StackTrace st) {
            controller.addError(e, st);
            // After forwarding the error, treat the stream as done so the
            // consumer sees `onDone` and can reconnect. (addError does not
            // close the controller by default; we close after the error to
            // keep semantics "stream terminates on any byte-stream error".)
            controller.close();
          },
          onDone: () {
            // The byte stream ended; flush any in-flight frame, then
            // close the controller so the consumer sees the stream end.
            dispatch();
            controller.close();
          },
          cancelOnError: false,
        );

        controller.onCancel = () async {
          await lineSub?.cancel();
        };
      } catch (e, st) {
        controller.addError(e, st);
        await controller.close();
      }
    });

    return controller.stream;
  }
}
