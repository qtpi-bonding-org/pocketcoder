import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

const _exemptions = <String>{
  'lib/presentation/core/widgets/pocketcoder_shell.dart', // owns the SingleChildScrollView this test guards against elsewhere
};

void main() {
  test('a PocketCoderShell body does not hand-roll SingleChildScrollView',
      () {
    final offenders = <String>[];
    for (final f in Directory('lib/presentation').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (_exemptions.any(f.path.endsWith)) continue;

      final content = f.readAsStringSync();
      if (!content.contains('PocketCoderShell(')) continue;
      if (!content.contains('SingleChildScrollView')) continue;

      final lines = content.split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('SingleChildScrollView')) {
          offenders.add('${f.path}:${i + 1}  ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: '''
PocketCoderShell already owns the clamp-and-scroll idiom via
`scrollable: true` -- a file that calls PocketCoderShell( has no reason to
also hand-roll a SingleChildScrollView. Pass `scrollable: true` (and
`scrollPadding:` if the body needs vertical padding) instead:

${offenders.join('\n')}
''');
  });
}
