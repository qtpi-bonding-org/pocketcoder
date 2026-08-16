import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketcoder_flutter/domain/deployment/server_tls_status.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/deployment_tls_monitor.dart';

void main() {
  test('reads the status route over plain HTTP and parses TLS state',
      () async {
    final client = MockClient((request) async {
      expect(request.url.scheme, 'http');
      expect(request.url.path, '/_pocketcoder/status.json');
      return http.Response(
        '{"schema":2,"tls":{"state":"rate_limited","hostname":"66-228-35-248.sslip.io","reason":"certificate authority rejected issuance"}}',
        200,
      );
    });
    final monitor = DeploymentTlsMonitor(client: client);

    final snapshot = await monitor.read('66-228-35-248.sslip.io');

    expect(snapshot.tls.state, ServerTlsState.rateLimited);
    expect(snapshot.tls.isRateLimited, isTrue);
    expect(snapshot.raw['schema'], 2);
  });

  test('throws when the status route returns a non-200', () async {
    final client = MockClient((request) async => http.Response('', 502));
    final monitor = DeploymentTlsMonitor(client: client);

    expect(
      () => monitor.read('66-228-35-248.sslip.io'),
      throwsA(isA<StateError>()),
    );
  });

  test('throws when the response body is not a JSON object', () async {
    final client = MockClient((request) async => http.Response('[]', 200));
    final monitor = DeploymentTlsMonitor(client: client);

    expect(
      () => monitor.read('66-228-35-248.sslip.io'),
      throwsA(isA<FormatException>()),
    );
  });
}
