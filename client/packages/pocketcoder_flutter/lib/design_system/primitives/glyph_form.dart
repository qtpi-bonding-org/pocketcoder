/// The delimiters that give a label its meaning, and the only place they live.
///
/// Each form says exactly one thing. Using one where another belongs is a
/// real error rather than a stylistic choice: `<deny>` and `[ deny ]` claim
/// different things about who is speaking and whether the reader may act.
///
/// Every delimiter in the interface is declared here so that no widget hand
/// writes one. `glyph_discipline_test.dart` fails on any literal that escapes.
enum GlyphForm {
  /// `[ ok ]` -- status the machine reports. Read-only; never a tap target.
  /// Also the checkbox (`[x]`) and the badge (`[ recommended ]`), which are
  /// states rather than actions.
  status('[ ', ' ]'),

  /// `<cancel>` -- a discrete button the machine offers. From whiptail, where
  /// brackets separate one choice from the next inside a modal.
  action('<', '>'),

  /// `> help me with setup` -- a prompt. The user's own voice answering a
  /// question, not a choice the machine is offering. A suggested reply is a
  /// conversational turn and takes the prompt character, never brackets.
  prompt('> ', ''),

  /// `* pocketbase` -- an item in a list. OpenRC's service prefix.
  item('* ', ''),

  /// `● system` -- a section header, whose colour carries aggregate state.
  section('● ', ''),

  /// A bare label. The nav footer uses this: a persistent status bar is not a
  /// modal, so its pillars are plain words and the reverse-video highlight
  /// carries both "this is a control" and "you are here".
  bare('', '');

  const GlyphForm(this.lead, this.trail);

  /// What precedes the label.
  final String lead;

  /// What follows it. Empty for the prefix-only forms.
  final String trail;

  /// Decorates [label], which must arrive undecorated.
  ///
  /// The assert is the point: every double-marker bug in this interface came
  /// from a call site adding a delimiter the widget also adds --
  /// `<<cancel>>`, `<[-] show concise>`, `<> what is a container?>`. Exactly
  /// one place decorates, and it is this one.
  String wrap(String label) {
    assert(
      !_looksDecorated(label),
      'Label "$label" already carries a glyph. Pass the bare text -- '
      'GlyphForm.$name adds "$lead"/"$trail" itself. Decorating at the call '
      'site produces a double marker.',
    );
    return '$lead$label$trail';
  }

  static bool _looksDecorated(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return false;
    for (final form in values) {
      if (form.lead.isEmpty) continue;
      if (trimmed.startsWith(form.lead.trim())) return true;
    }
    return false;
  }
}
