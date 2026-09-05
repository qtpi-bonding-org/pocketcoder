import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Terminal widget spec §0 "Screen structure": a screen's content is
/// left-aligned at one indent from the safe area and NEVER CENTERED. A
/// `Center` (or `Align(alignment: Alignment.center)`) applied directly to a
/// `PocketCoderShell` body -- or to the shared onboarding chrome wrapper,
/// which is the same thing one level removed -- makes a short screen float
/// in the middle of the viewport with dead space above and below, instead
/// of landing at a consistent top position on every navigation.
/// `Align(alignment: Alignment.topCenter, ...)` is the correct way to keep
/// a tablet max-width clamp horizontally centered without touching the
/// vertical axis, and is not flagged.
///
/// This intentionally does not flag bare `return Center(...)` /
/// `=> Center(...)` in general: that shape is extremely common for a
/// transient loading/empty/error placeholder rendered inside a region a
/// parent `Expanded` already bounds (e.g. `Expanded(child: state.isLoading
/// ? Center(child: Spinner()) : ListView(...))`), which is normal list-state
/// UX, not the whole-screen-floats-in-the-middle bug this test guards
/// against. See the 2026-09-04 screen-layout audit for the full survey.
const _exemptions = <String>{
  // (none currently in FOSS -- every screen needing a tablet max-width
  // clamp uses Align(alignment: Alignment.topCenter, ...) instead of
  // Center; see 2026-09-04 screen-layout audit. PRO's
  // initialization_progress_view.dart also wraps its body in Center, but
  // its Column has an Expanded child so the Center is vertically inert --
  // that file lives outside this package's lib/presentation and isn't
  // scanned here.)
};

void main() {
  test('no screen centers its body vertically', () {
    final offenders = <String>[];
    final bodyCenterPatterns = [
      RegExp(r'body:\s*Center\('),
      RegExp(r'body:\s*Align\(\s*alignment:\s*Alignment\.center\b'),
    ];
    for (final f in Directory('lib/presentation').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (_exemptions.any(f.path.endsWith)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final isBodyCenter = bodyCenterPatterns.any((p) => p.hasMatch(line));
        // onboarding_content_shell.dart is the shared chrome wrapper every
        // onboarding screen renders through -- its own top-level `return
        // Center(...)` is the exact same violation as `body: Center(...)`
        // one level removed, so it gets its own check rather than the
        // (much too broad, and legitimately common elsewhere) bare
        // `return Center(` pattern.
        final isSharedShellCenter =
            f.path.endsWith('onboarding_content_shell.dart') &&
                line.trim().startsWith('return Center(');
        if (isBodyCenter || isSharedShellCenter) {
          offenders.add('${f.path}:${i + 1}  ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: '''
Content is left-aligned at one indent from the safe area, NEVER CENTERED
(terminal widget spec §0) -- a Center wrapping the whole screen body makes
a short screen float in the middle of the viewport instead of landing at a
consistent top position on every navigation. Use
Align(alignment: Alignment.topCenter, ...) instead if a tablet max-width
clamp is needed -- same horizontal centering, but the vertical axis is
never touched:
${offenders.join('\n')}
''');
  });
}
