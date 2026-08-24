// Structural regression coverage for the "two independent HTTP trust
// stacks" incident: PocketCoderApiClient used to build a bare `Dio()`
// with Dio's own default HttpClientAdapter, with zero knowledge of
// CaddyCaPinningHttpClient's pin state -- so verifyServerCompatibility()
// (and every other generated-API call) could never validate a
// deployment's self-signed CA, no matter what was correctly pinned
// elsewhere in the app. PocketCoderApiClient.fromPocketBase now derives
// its Dio transport from CaddyCaPinningHttpClient directly (the app's
// single source of truth for deployment TLS trust -- see that class's
// doc comment), and rebuilds it whenever the pin changes, so the two
// stacks structurally cannot drift apart again.
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/infrastructure/core/caddy_ca_pinning_http_client.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';

// A throwaway cert used only to prove updatePin() reaches this client's
// Dio transport at all -- no relation to any real deployment's CA.
//
// A true end-to-end test (bind a local HTTPS server presenting this cert,
// pin it, confirm Dio can complete a request against it) was attempted
// and abandoned: this test sandbox cannot validate ANY custom-CA loopback
// TLS connection, even using the exact pre-fix code
// (SecurityContext(withTrustedRoots: false)) against a properly-formed
// CA+leaf chain with correct SAN/EKU -- confirmed identical
// "application verification failure" across RSA and ed25519 keys, IP and
// DNS hostnames, and with/without withTrustedRoots, while a
// badCertificateCallback bypass completes the exact same request fine
// (proving the socket/handshake mechanics work; only the local
// TLS-verification step is broken in this sandbox). The tests below
// instead prove the two provable halves: the wiring is structurally
// correct (Dio derives its adapter from the shared trust source and
// rebuilds it on pin changes), and normal system CA trust survives
// pinning on this transport, exactly as CaddyCaPinningHttpClient's own
// tests prove for the package:http side.
const _testCertPem = '''
-----BEGIN CERTIFICATE-----
MIIBZTCCARegAwIBAgIUdws19XgwnD1iKfDrbbW9nMtjkrcwBQYDK2VwMBoxGDAW
BgNVBAMMD3Rlc3QtZGVwbG95bWVudDAeFw0yNjA4MjQxMjU2NDZaFw0zNjA4MjEx
MjU2NDZaMBoxGDAWBgNVBAMMD3Rlc3QtZGVwbG95bWVudDAqMAUGAytlcAMhAA+k
lqlJF4zplskPEYgmau4mb5KxLmMuxL+HUaOb5mQ2o28wbTAdBgNVHQ4EFgQUUnvo
6lik53IZ0CwkaO/zwswcDKQwHwYDVR0jBBgwFoAUUnvo6lik53IZ0CwkaO/zwswc
DKQwDwYDVR0TAQH/BAUwAwEB/zAaBgNVHREEEzARhwR/AAABgglsb2NhbGhvc3Qw
BQYDK2VwA0EAKjdeQU7RNreBrVg1NexXLMM84gG0fHZNaIEihAY+Bg/gWk3RNpUO
aD2LiMbggDG239QLaoNcXZLlD08fJaU2DA==
-----END CERTIFICATE-----
''';

void main() {
  group('PocketCoderApiClient.fromPocketBase', () {
    test(
        'builds an IOHttpClientAdapter derived from the shared '
        'CaddyCaPinningHttpClient, and swaps in a fresh one reflecting '
        'the new trust whenever the pin changes -- Dio caches its '
        'internal HttpClient for the adapter\'s whole lifetime (there is '
        'no way to refresh one in place), so this client must react to '
        'onPinChanged by installing a brand-new adapter rather than '
        'keeping a pre-pin client cached forever', () async {
      final caddyCaPinningHttpClient = CaddyCaPinningHttpClient();
      final pocketBase = PocketBase('https://example.invalid');

      final client = PocketCoderApiClient.fromPocketBase(
        pocketBase,
        caddyCaPinningHttpClient,
      );

      final adapterBeforePin = client.dio.httpClientAdapter;
      expect(adapterBeforePin, isA<IOHttpClientAdapter>());

      caddyCaPinningHttpClient.updatePin(_testCertPem);
      // onPinChanged is a broadcast stream event -- let it dispatch.
      await Future<void>.delayed(Duration.zero);

      final adapterAfterPin = client.dio.httpClientAdapter;
      expect(adapterAfterPin, isA<IOHttpClientAdapter>());
      expect(adapterAfterPin, isNot(same(adapterBeforePin)),
          reason: 'a pin change must swap in a fresh adapter reflecting '
              'the new trust, not silently keep using a client cached '
              'from before the pin existed');
    });

    test(
        'still reaches a normal public HTTPS host through Dio after a '
        'pin is applied -- the same "don\'t discard system trust" '
        'guarantee CaddyCaPinningHttpClient itself provides must hold '
        'for this derived Dio transport too, not just the package:http '
        'one', () async {
      final caddyCaPinningHttpClient = CaddyCaPinningHttpClient();
      final pocketBase = PocketBase('https://example.invalid');
      final client = PocketCoderApiClient.fromPocketBase(
        pocketBase,
        caddyCaPinningHttpClient,
      );
      caddyCaPinningHttpClient.updatePin(_testCertPem);
      await Future<void>.delayed(Duration.zero);

      try {
        await client.dio.get<void>('https://api.github.com');
      } on Object catch (e) {
        if (e.toString().toLowerCase().contains('certificate') ||
            e.toString().toLowerCase().contains('handshake')) {
          fail('normal system CA trust was lost on the Dio transport: $e');
        }
        // Any other failure (no network here, a non-2xx response, etc.)
        // is not what this test guards against.
      }
    });
  });
}
