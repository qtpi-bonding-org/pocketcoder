import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/design_system/primitives/shell_footer.dart';

void main() {
  test('a wizard footer cannot exist without a position', () {
    expect(
      () => WizardFooter(step: 0, totalSteps: 7, onNext: () {}),
      throwsAssertionError,
    );
    expect(
      () => WizardFooter(step: 8, totalSteps: 7, onNext: () {}),
      throwsAssertionError,
    );
    expect(
      WizardFooter(step: 3, totalSteps: 7, onNext: () {}).step,
      3,
    );
  });

  test('a pillar footer has no concept of a step', () {
    // A destination is not a step. There must be no way to put a (3/7)
    // counter inside the app.
    const footer = PillarFooter(NavPillar.chat);
    expect(footer.toString(), isNot(contains('step')));
  });
}
