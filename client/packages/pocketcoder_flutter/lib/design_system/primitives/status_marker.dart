import 'package:pocketcoder_flutter/design_system/primitives/text_role.dart';

/// A status the machine reports. Renders as `[ word ]` with dim brackets and
/// a colored word -- the OpenRC detail where punctuation is structural and only
/// the word carries meaning.
///
/// The bracket characters live here and nowhere else. No API accepts an
/// already-bracketed string, so `[ ok ]` cannot be typed by hand.
enum StatusMarker {
  ok('ok', TextRole.ok),
  attention('!!', TextRole.warn),
  failed('!!', TextRole.fail),
  pending('..', TextRole.label);

  const StatusMarker(this.word, this.role);
  final String word;
  final TextRole role;
}
