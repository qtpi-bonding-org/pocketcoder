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

  // Regression test: ServerSshHostKey.tryParse's fingerprint regex was
  // MD5-shaped while dartssh2's onVerifyHostKey (the only consumer) needs
  // a SHA256 fingerprint -- confirmed live, this silently rejected every
  // real fingerprint the box ever published, with no test catching it.
  test('parses a SHA256-formatted ssh host key fingerprint', () {
    final document = ServerStatusDocument.tryParse(jsonEncode({
      'schema': 2,
      'runId': 'run-1',
      'phase': 'bootstrap_complete',
      'updatedAt': '2026-08-15T00:00:00Z',
      'sshHostKey': {
        'type': 'ssh-ed25519',
        'fingerprint': 'SHA256:nA1lraVKLCs/jFY8qc3vOUIJzb6P/xMGFrdFx0A4JR8',
      },
    }));

    expect(document?.sshHostKey?.type, 'ssh-ed25519');
    expect(
      document?.sshHostKey?.fingerprint,
      'SHA256:nA1lraVKLCs/jFY8qc3vOUIJzb6P/xMGFrdFx0A4JR8',
    );
  });

  test('rejects an MD5-formatted ssh host key fingerprint', () {
    final document = ServerStatusDocument.tryParse(jsonEncode({
      'schema': 2,
      'runId': 'run-1',
      'phase': 'bootstrap_complete',
      'updatedAt': '2026-08-15T00:00:00Z',
      'sshHostKey': {
        'type': 'ssh-ed25519',
        'fingerprint': 'MD5:00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd:ee:ff',
      },
    }));

    expect(document?.sshHostKey, isNull);
  });
}
