// Thin wrapper around the `ag_ui` package's decoder — the single point where
// raw AG-UI wire JSON becomes a typed Dart event. Nothing downstream
// (AgentStreamClient, the cache, ConversationReducer) parses AG-UI JSON by
// hand; they all consume [AguiEvent] via this file.
import 'package:ag_ui/ag_ui.dart';
import 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart';

export 'package:ag_ui_widgets_flutter/ag_ui_widgets_flutter.dart'
    show isReplaceMarker;

/// Re-export of ag_ui's event base type under a PocketCoder-local name, so
/// call sites don't need to import `package:ag_ui/ag_ui.dart` directly just
/// to spell the type.
typedef AguiEvent = BaseEvent;

const _decoder = EventDecoder();

/// One decoded AG-UI frame. [rawJson] is retained verbatim (not re-encoded)
/// so the cache (`AgentCacheDb.upsertEvent`) can persist the exact bytes the
/// server sent without a lossy round-trip through Dart's encoder.
typedef DecodedFrame = ({String rawJson, AguiEvent event});

/// Decodes one AG-UI wire event (the JSON that follows an SSE `data:` line)
/// into a [DecodedFrame]. Throws [DecodingError] (from `ag_ui`) on malformed
/// or schema-invalid input — callers decide whether that's fatal for a
/// single frame or the whole connection.
DecodedFrame decodeAguiFrame(String dataJson) {
  final event = _decoder.decode(dataJson);
  return (rawJson: dataJson, event: event);
}
