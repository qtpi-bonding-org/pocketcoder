import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_pro/domain/deployment/harness_catalog.dart';

void main() {
  final catalog = DeploymentHarnessCatalog.bundled;

  test('bundled catalog defaults to Goose and preserves canonical order', () {
    expect(catalog.schemaVersion, 1);
    expect(catalog.initialSelection, ['goose']);
    expect(
      catalog.harnesses.map((harness) => harness.id),
      ['goose', 'claude-code', 'codex', 'opencode'],
    );
    expect(
      catalog.canonicalize(['codex', 'goose']),
      ['goose', 'codex'],
    );
  });

  test('selection must be non-empty, duplicate-free, and known', () {
    expect(() => catalog.canonicalize([]), throwsFormatException);
    expect(
      () => catalog.canonicalize(['goose', 'goose']),
      throwsFormatException,
    );
    expect(() => catalog.canonicalize(['unknown']), throwsFormatException);
  });

  test('parser rejects unknown catalog fields', () {
    expect(
      () => DeploymentHarnessCatalog.parse(
        '{"schemaVersion":1,"defaultHarness":"goose",'
        '"harnesses":[],"unexpected":true}',
      ),
      throwsFormatException,
    );
  });
}
