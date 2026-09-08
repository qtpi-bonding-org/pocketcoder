import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:pocketcoder_flutter/domain/deployment/caddy_ca_pin.dart';
import 'package:pocketcoder_flutter/domain/os_control/i_root_ssh_command_runner.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command.dart';
import 'package:pocketcoder_flutter/domain/os_control/root_ssh_command_result.dart';
import 'package:pocketcoder_flutter/infrastructure/core/caddy_ca_pinning_http_client.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/ca_pin_fetcher.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/ca_pin_mutex.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/ca_pin_recovery.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/caddy_ca_pin_store.dart';

class MockSshRunner extends Mock implements IRootSshCommandRunner {}

class FakeDeploymentLookup implements CurrentDeploymentLookup {
  FakeDeploymentLookup(this.current);
  @override
  final ({String instanceId, String host})? current;
}

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

    test(
        'retries and succeeds after recovery even when the durable pin was '
        'already correct (recoverIfStale returns false) -- regression for a '
        'cold-boot client that never loaded ANY pin yet this session: SSH '
        'refetch legitimately reports "fingerprint unchanged" (the '
        'persisted pin was never wrong), but updatePin() still installs it '
        'into this LIVE client for the first time, so the retry must still '
        'happen -- confirmed live, this made every cold boot against a '
        'healthy, already-provisioned deployment permanently fail with '
        'CERTIFICATE_VERIFY_FAILED', () async {
      registerFallbackValue(RootSshCommand.exportCaddyCaFingerprint);
      final tempDir = await Directory.systemTemp.createTemp('ca_pin_test');
      addTearDown(() => tempDir.delete(recursive: true));
      final certPath = p.join(tempDir.path, 'cert.pem');
      final keyPath = p.join(tempDir.path, 'key.pem');
      final genResult = await Process.run('openssl', [
        'req', '-x509', '-newkey', 'rsa:2048', '-keyout', keyPath,
        '-out', certPath, '-days', '1', '-nodes', '-subj', '/CN=127.0.0.1',
        '-addext', 'subjectAltName=IP:127.0.0.1',
        '-addext', 'extendedKeyUsage=serverAuth',
      ]);
      expect(genResult.exitCode, 0,
          reason: 'openssl cert generation failed: ${genResult.stderr}');
      final certPem = await File(certPath).readAsString();

      final serverContext = SecurityContext()
        ..useCertificateChain(certPath)
        ..usePrivateKey(keyPath);
      final server = await HttpServer.bindSecure(
          InternetAddress.loopbackIPv4, 0, serverContext);
      addTearDown(server.close);
      unawaited(server.first.then((request) async {
        request.response.statusCode = 200;
        await request.response.close();
      }));

      FlutterSecureStorage.setMockInitialValues({});
      final pinStore = CaddyCaPinStore(FlutterSecureStorage());
      const instanceId = 'test-instance';
      const fingerprint = 'unchanged-fingerprint';
      await pinStore.write(
        deploymentId: instanceId,
        pin: CaddyCaPin(fingerprint: fingerprint, certificatePem: certPem),
      );

      final sshRunner = MockSshRunner();
      when(() => sshRunner.run(
            instanceId: any(named: 'instanceId'),
            host: any(named: 'host'),
            command: RootSshCommand.exportCaddyCaFingerprint,
          )).thenAnswer((_) async => RootSshCommandResult(
            exitCode: 0,
            stdout: '{"fingerprint":"$fingerprint",'
                '"certificatePemBase64":"${base64.encode(utf8.encode(certPem))}"}',
            stderr: '',
          ));

      final client = CaddyCaPinningHttpClient();
      final fetcher = CaPinFetcher(
        sshCommandRunner: sshRunner,
        pinStore: pinStore,
        pinningHttpClient: CaddyCaPinningHttpClientAdapter(client),
        mutex: CaPinMutex(),
      );
      final recovery = CaPinRecovery(
        caPinFetcher: fetcher,
        currentDeployment:
            FakeDeploymentLookup((instanceId: instanceId, host: '127.0.0.1')),
      );
      client.attachRecovery(recovery);

      // No pin loaded yet this session -- the first attempt must fail
      // native cert validation against the self-signed server, exactly
      // like a real cold boot.
      final response =
          await client.get(Uri.parse('https://127.0.0.1:${server.port}/'));

      expect(response.statusCode, 200);
    }, testOn: 'vm');
  });
}
