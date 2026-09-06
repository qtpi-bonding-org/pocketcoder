import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Screens deliberately exempt from carrying a footer: each offers a
/// choice between paths rather than occupying one step of a linear flow.
const _branchPointScreens = {
  'lib/presentation/onboarding/widgets/onboarding_view.dart',
  'lib/presentation/onboarding/widgets/welcome_view.dart',
};

void main() {
  test('every shell call site supplies a footer, except declared branch points',
      () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      if (!src.contains('PocketCoderShell(')) continue;
      if (src.contains('PocketCoderShell(') && !src.contains('footer:')) {
        offenders.add(f.path);
      }
    }
    final unexpected =
        offenders.where((path) => !_branchPointScreens.contains(path));
    expect(unexpected, isEmpty,
        reason: 'every PocketCoderShell call site must supply a footer '
            'unless it is a declared branch point (§11) -- a wizard or '
            'pillar strip cannot be implied, only given, and a new '
            'footer-less screen must be added to _branchPointScreens '
            'deliberately, not by accident');
  });
}
