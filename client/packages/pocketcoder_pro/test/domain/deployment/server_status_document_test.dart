import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_pro/domain/deployment/server_status_document.dart';

void main() {
  test('reads optional backend-owned phase progress', () {
    final document = ServerStatusDocument(
      schema: 2,
      runId: 'run-1',
      phase: 'loading_images',
      updatedAt: DateTime.utc(2026, 8, 11),
      raw: const {
        'progress': {'provision': 1, 'deploy': 0.42},
      },
    );

    expect(document.progressFor('provision'), 1);
    expect(document.progressFor('deploy'), 0.42);
    expect(document.progressFor('unknown'), isNull);
  });

  test('rejects invalid progress rather than implying precision', () {
    final document = ServerStatusDocument(
      schema: 1,
      runId: 'run-1',
      phase: 'loading_images',
      updatedAt: DateTime.utc(2026, 8, 11),
      raw: const {'deployProgress': 42},
    );

    expect(document.progressFor('deploy'), isNull);
  });
}
