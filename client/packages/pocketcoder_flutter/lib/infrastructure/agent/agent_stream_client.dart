// Agent-specific adapter over the protocol-agnostic SSE client. Reconnection is
// caller-driven: one connect call owns exactly one connection attempt.
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agui_decode.dart';
import 'package:pocketcoder_flutter/infrastructure/core/api_endpoints.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketbase_auth_header.dart';
import 'package:pocketcoder_flutter/infrastructure/core/sse_stream_client.dart';

/// One decoded SSE frame containing the hub sequence and typed AG-UI event.
typedef StreamFrame = ({int seq, String rawJson, AguiEvent event});

class AgentStreamException implements Exception {
  const AgentStreamException(this.statusCode);

  final int statusCode;

  bool get isRetryable =>
      statusCode == 408 ||
      statusCode == 425 ||
      statusCode == 429 ||
      statusCode >= 500;

  @override
  String toString() => 'Agent stream returned HTTP $statusCode';
}

/// Authenticated adapter for the c1 agent SSE endpoint.
@lazySingleton
class AgentStreamClient {
  final PocketBase _pb;
  final SseStreamClient _sse;

  AgentStreamClient({
    required PocketBase pocketBase,
    required http.Client httpClient,
  })  : _pb = pocketBase,
        _sse = SseStreamClient(httpClient: httpClient);

  /// Opens one connection and maps generic SSE records to AG-UI frames.
  Stream<StreamFrame> connect(String chatId, {required int cursor}) {
    final controller = StreamController<StreamFrame>();

    final authHeader = pocketBaseAuthHeaderValue(_pb);
    if (authHeader == null) {
      // Preserve the stream-based error contract while ensuring the request
      // is never opened without authentication.
      Future<void>(() async {
        controller.addError(
          StateError('Agent stream requires an authenticated session'),
        );
        await controller.close();
      });
      return controller.stream;
    }
    final request = http.Request(
      'GET',
      Uri.parse(
        '${_pb.baseURL}${StreamingEndpoints.agentStream(chatId)}?cursor=$cursor',
      ),
    )..headers['Authorization'] = authHeader;

    // `_sse.connect()` and the `.listen()` below both run synchronously, so
    // there is no window in which this call's own cancellation could arrive
    // before `frameSub` exists -- `controller.onCancel` can reference it
    // directly. This also keeps each connect() call's cancellation scoped to
    // itself: routing an early cancel through the shared `_sse.cancel()`
    // (which aborts every connection this singleton owns) would wrongly
    // abort unrelated concurrent chat streams.
    final frames = _sse.connect(() => request);
    final frameSub = frames.listen(
      (frame) {
        // The agent protocol uses an integer id. If the server omits it, or
        // supplies a non-integer value, preserve the existing seq 0 fallback.
        final parsedId = int.tryParse(frame.id ?? '');
        try {
          final decoded = decodeAguiFrame(frame.data);
          controller.add((
            seq: parsedId ?? 0,
            rawJson: decoded.rawJson,
            event: decoded.event,
          ));
        } catch (e, st) {
          // A malformed frame is reported without terminating the stream.
          controller.addError(e, st);
        }
      },
      onError: (Object e, StackTrace st) {
        final error =
            e is SseHttpException ? AgentStreamException(e.statusCode) : e;
        controller.addError(error, st);
        controller.close();
      },
      onDone: controller.close,
      cancelOnError: false,
    );
    controller.onCancel = frameSub.cancel;

    return controller.stream;
  }

  /// Aborts all agent connections owned by this client.
  Future<void> cancel() => _sse.cancel();
}
