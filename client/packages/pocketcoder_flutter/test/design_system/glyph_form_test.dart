import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/glyph_form.dart';

void main() {
  test('each form wraps its label the way the spec says', () {
    expect(GlyphForm.status.wrap('ok'), '[ ok ]');
    expect(GlyphForm.action.wrap('cancel'), '<cancel>');
    expect(GlyphForm.prompt.wrap('help me with setup'),
        '> help me with setup');
    expect(GlyphForm.item.wrap('pocketbase'), '* pocketbase');
    expect(GlyphForm.section.wrap('system'), '● system');
    expect(GlyphForm.bare.wrap('config'), 'config');
  });

  test('no two forms share a lead', () {
    // Two forms with the same opening glyph would be indistinguishable to a
    // reader, which defeats the whole vocabulary.
    final leads = GlyphForm.values
        .map((f) => f.lead)
        .where((l) => l.isNotEmpty)
        .toList();
    expect(leads.toSet(), hasLength(leads.length), reason: 'leads: $leads');
  });

  test('an already-decorated label is rejected, not double-wrapped', () {
    // Every double-marker bug in this interface came from a call site adding
    // a delimiter the widget also adds: <<cancel>>, <[-] show concise>,
    // <> what is a container?>.
    for (final label in [
      '<cancel>',
      '[ ok ]',
      '> help me with setup',
      '* pocketbase',
      '● system',
      '[-] show concise code',
    ]) {
      expect(() => GlyphForm.action.wrap(label), throwsAssertionError,
          reason: '"$label" is already decorated and must be refused');
    }
  });

  test('a bare label passes, including ones that merely contain a glyph', () {
    // Only a LEADING delimiter is decoration. A label may legitimately
    // contain one of these characters mid-string.
    expect(() => GlyphForm.action.wrap('cancel'), returnsNormally);
    expect(() => GlyphForm.action.wrap('restart 6 services'), returnsNormally);
    expect(() => GlyphForm.prompt.wrap("I'll set it up"), returnsNormally);
    expect(() => GlyphForm.action.wrap('a > b'), returnsNormally);
  });

  test('the prompt form is prefix-only', () {
    // A prompt is not a wrapper. `> reply` is the user speaking; `<reply>`
    // would be the machine offering a choice, which is a different claim.
    expect(GlyphForm.prompt.trail, isEmpty);
    expect(GlyphForm.item.trail, isEmpty);
    expect(GlyphForm.section.trail, isEmpty);
  });

  test('only status and action are wrappers', () {
    final wrappers =
        GlyphForm.values.where((f) => f.trail.isNotEmpty).toSet();
    expect(wrappers, {GlyphForm.status, GlyphForm.action});
  });
}
