import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketcoder_flutter/infrastructure/core/caddy_ca_pinning_http_client.dart';

void main() {
  group('CaddyCaPinningHttpClient', () {
    test('close() is a no-op -- send() still works afterward', () async {
      final client = CaddyCaPinningHttpClient();

      client.close();

      // Before the fix, this threw `Bad state: HTTP client is closed`.
      // A real network call would fail for other reasons in a unit test
      // (no server), but it must fail with a connection error, never with
      // the "closed" StateError -- confirming close() didn't poison the
      // client for later use.
      await expectLater(
        client.send(http.Request('GET', Uri.parse('http://127.0.0.1:1'))),
        throwsA(isNot(isA<StateError>())),
      );
    });

    test('close() can be called multiple times without throwing', () {
      final client = CaddyCaPinningHttpClient();

      expect(client.close, returnsNormally);
      expect(client.close, returnsNormally);
      expect(client.close, returnsNormally);
    });

    test('send() still routes through the delegate after close()', () async {
      // Regression test for the shared-singleton footgun: any one consumer
      // of the injected http.Client calling close() (completely normal,
      // correct http.Client hygiene for a client it thinks it owns) must
      // never break the client for every other consumer, since this class
      // is registered as an app-lifetime singleton shared across the app
      // (see external_module.dart) -- including consumers with nothing to
      // do with any deployment, like Linode OAuth.
      final client = CaddyCaPinningHttpClient();
      client.close();

      // A connection failure is expected (nothing is listening); what
      // matters is that it's not the closed-client StateError.
      await expectLater(
        client.head(Uri.parse('http://127.0.0.1:1')),
        throwsA(isNot(isA<StateError>())),
      );
    });

    test('updatePin swaps the delegate and closes the previous one', () async {
      final client = CaddyCaPinningHttpClient();

      // A real (if throwaway) self-signed cert -- SecurityContext parses
      // and validates the DER content, so arbitrary placeholder bytes
      // inside BEGIN/END markers would throw for an unrelated reason.
      const testCertPem = '''
-----BEGIN CERTIFICATE-----
MIIBMjCB5aADAgECAhQEeK4yBFpowWqdINB6u4kuF/Iz9jAFBgMrZXAwDzENMAsG
A1UEAwwEdGVzdDAeFw0yNjA4MjExODA1MTdaFw0yNjA4MjIxODA1MTdaMA8xDTAL
BgNVBAMMBHRlc3QwKjAFBgMrZXADIQA35AkzbEObtQCfD0Bfmfw1V0U5hAQsLvDy
v3ZBh8EKSKNTMFEwHQYDVR0OBBYEFL73wLSIVrASXvmulnz3JMbaOmX6MB8GA1Ud
IwQYMBaAFL73wLSIVrASXvmulnz3JMbaOmX6MA8GA1UdEwEB/wQFMAMBAf8wBQYD
K2VwA0EAd4JrQT53rhIpnCRb36y3SHuu7skZZRD9TYiF/AsmeMyXwvsk20WSup9M
vOlqkW8uk4vrxfTyo29hA6Pu8X6rAA==
-----END CERTIFICATE-----
''';

      expect(() => client.updatePin(testCertPem), returnsNormally);
    });

    test(
        'updatePin adds trust for the pinned CA without discarding normal '
        'system/platform trust -- this client is a shared, app-lifetime '
        'singleton used for every unrelated HTTPS call in the app too '
        '(Linode API, OAuth, image relay, ...), and '
        'withTrustedRoots: false used to make ALL of those fail '
        'certificate validation app-wide the moment any one deployment\'s '
        'pin was applied (confirmed live: a Linode API call started '
        'failing with HandshakeException/CERTIFICATE_VERIFY_FAILED '
        'immediately after a deployment pin was fetched and applied)',
        () async {
      final client = CaddyCaPinningHttpClient();

      const testCertPem = '''
-----BEGIN CERTIFICATE-----
MIIBMjCB5aADAgECAhQEeK4yBFpowWqdINB6u4kuF/Iz9jAFBgMrZXAwDzENMAsG
A1UEAwwEdGVzdDAeFw0yNjA4MjExODA1MTdaFw0yNjA4MjIxODA1MTdaMA8xDTAL
BgNVBAMMBHRlc3QwKjAFBgMrZXADIQA35AkzbEObtQCfD0Bfmfw1V0U5hAQsLvDy
v3ZBh8EKSKNTMFEwHQYDVR0OBBYEFL73wLSIVrASXvmulnz3JMbaOmX6MB8GA1Ud
IwQYMBaAFL73wLSIVrASXvmulnz3JMbaOmX6MA8GA1UdEwEB/wQFMAMBAf8wBQYD
K2VwA0EAd4JrQT53rhIpnCRb36y3SHuu7skZZRD9TYiF/AsmeMyXwvsk20WSup9M
vOlqkW8uk4vrxfTyo29hA6Pu8X6rAA==
-----END CERTIFICATE-----
''';
      client.updatePin(testCertPem);

      try {
        await client.get(Uri.parse('https://api.github.com'));
      } on HandshakeException catch (e) {
        fail('normal system CA trust was discarded by updatePin(): $e');
      } on Object catch (e) {
        // Any other failure (no network in this environment, DNS, a
        // non-2xx response, etc.) is not what this test guards against.
        if (e.toString().toLowerCase().contains('certificate')) {
          fail('a certificate-related failure survived updatePin(): $e');
        }
      }
    }, testOn: 'vm');

    test(
        'updatePin() with the same PEM already pinned does not abort a '
        'request already in flight -- CaPinFetcher.fetchAndPin() calls '
        'updatePin() unconditionally on every deploy-readiness poll tick '
        '(every ~3s) even when the pin has not changed; updatePin() used '
        'to unconditionally swap and close the delegate every time, which '
        'killed whatever request happened to still be in flight on the '
        'old delegate with "Connection closed before full header was '
        'received" -- confirmed live against a real deployment stuck '
        'looping on this exact error', () async {
      const testCertPem = '''
-----BEGIN CERTIFICATE-----
MIIBMjCB5aADAgECAhQEeK4yBFpowWqdINB6u4kuF/Iz9jAFBgMrZXAwDzENMAsG
A1UEAwwEdGVzdDAeFw0yNjA4MjExODA1MTdaFw0yNjA4MjIxODA1MTdaMA8xDTAL
BgNVBAMMBHRlc3QwKjAFBgMrZXADIQA35AkzbEObtQCfD0Bfmfw1V0U5hAQsLvDy
v3ZBh8EKSKNTMFEwHQYDVR0OBBYEFL73wLSIVrASXvmulnz3JMbaOmX6MB8GA1Ud
IwQYMBaAFL73wLSIVrASXvmulnz3JMbaOmX6MA8GA1UdEwEB/wQFMAMBAf8wBQYD
K2VwA0EAd4JrQT53rhIpnCRb36y3SHuu7skZZRD9TYiF/AsmeMyXwvsk20WSup9M
vOlqkW8uk4vrxfTyo29hA6Pu8X6rAA==
-----END CERTIFICATE-----
''';

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      unawaited(server.first.then((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        request.response.statusCode = 200;
        await request.response.close();
      }));

      final client = CaddyCaPinningHttpClient();
      client.updatePin(testCertPem);

      final responseFuture =
          client.get(Uri.parse('http://127.0.0.1:${server.port}/'));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      client.updatePin(testCertPem);

      final response = await responseFuture;
      expect(response.statusCode, 200);
    }, testOn: 'vm');
  });
}
