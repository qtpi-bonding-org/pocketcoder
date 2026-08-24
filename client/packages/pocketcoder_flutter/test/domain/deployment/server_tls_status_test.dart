import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_pro/domain/deployment/server_tls_status.dart';

void main() {
  test('parses trusted and rate-limited TLS states', () {
    final ready = ServerStatusSnapshot.fromJson({
      'phase': 'configuring_operating_system',
      'tls': {
        'state': 'ready',
        'hostname': '66-228-35-248.sslip.io',
        'issuer': 'Let\'s Encrypt',
      },
    });
    expect(ready.tls.isTrusted, isTrue);
    expect(ready.raw['phase'], 'configuring_operating_system');

    final limited = ServerTlsStatus.fromJson({'state': 'rate_limited'});
    expect(limited.isRateLimited, isTrue);
  });
}
