import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/deployment/server_status_document.dart';
import 'package:pocketcoder_flutter/domain/deployment/server_tls_status.dart';

void main() {
  test('parses a schema-2 document\'s tls state', () {
    final document = ServerStatusDocument.tryParse(jsonEncode({
      'schema': 2,
      'runId': 'run-1',
      'phase': 'waiting_for_caddy',
      'updatedAt': '2026-08-15T00:00:00Z',
      'tls': {
        'state': 'ready',
        'hostname': '66-228-35-248.sslip.io',
        'issuer': 'Let\'s Encrypt',
      },
    }));

    expect(document?.tls?.state, ServerTlsState.ready);
    expect(document?.tls?.isTrusted, isTrue);
  });

  test('leaves tls null when the server has not published it yet', () {
    final document = ServerStatusDocument.tryParse(jsonEncode({
      'schema': 1,
      'runId': 'run-1',
      'phase': 'configuring_operating_system',
      'updatedAt': '2026-08-15T00:00:00Z',
    }));

    expect(document?.tls, isNull);
  });
}
