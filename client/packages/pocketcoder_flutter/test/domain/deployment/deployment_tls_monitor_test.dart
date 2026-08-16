import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/deployment/server_tls_status.dart';

void main() {
  test('rate-limited status is represented distinctly', () {
    final status = ServerStatusSnapshot.fromJson({
      'schema': 2,
      'tls': {
        'state': 'rate_limited',
        'hostname': '66-228-35-248.sslip.io',
        'reason': 'certificate authority rejected issuance',
      },
    });
    expect(status.tls.state, ServerTlsState.rateLimited);
    expect(status.tls.reason, contains('rejected'));
  });
}
