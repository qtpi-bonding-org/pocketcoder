import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/deployment/certificate_bundle.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/certificate_bundle_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  const bundle = CertificateBundle(
    hostname: '66-228-35-248.sslip.io',
    issuer: 'acme-v02.api.letsencrypt.org-directory',
    certificatePem: 'CERTIFICATE',
    privateKeyPem: 'PRIVATE KEY',
  );

  test('round trips a bundle keyed by deployment and hostname', () async {
    final store = CertificateBundleStore(const FlutterSecureStorage());

    await store.write(deploymentId: 'instance-1', bundle: bundle);
    final read = await store.read(
      deploymentId: 'instance-1',
      hostname: bundle.hostname,
    );

    expect(read?.hostname, bundle.hostname);
    expect(read?.privateKeyPem, bundle.privateKeyPem);
  });

  test('does not return a bundle for a different hostname', () async {
    final store = CertificateBundleStore(const FlutterSecureStorage());
    await store.write(deploymentId: 'instance-1', bundle: bundle);

    final read = await store.read(
      deploymentId: 'instance-1',
      hostname: '203-0-113-9.sslip.io',
    );

    expect(read, isNull);
  });

  test('does not return a bundle cached under a different deployment',
      () async {
    final store = CertificateBundleStore(const FlutterSecureStorage());
    await store.write(deploymentId: 'instance-1', bundle: bundle);

    final read = await store.read(
      deploymentId: 'instance-2',
      hostname: bundle.hostname,
    );

    expect(read, isNull);
  });

  test('returns null for a corrupted stored value', () async {
    FlutterSecureStorage.setMockInitialValues({
      'pocketcoder.caddy-certificate.instance-1.${bundle.hostname}':
          'not json',
    });
    final store = CertificateBundleStore(const FlutterSecureStorage());

    final read = await store.read(
      deploymentId: 'instance-1',
      hostname: bundle.hostname,
    );

    expect(read, isNull);
  });
}
