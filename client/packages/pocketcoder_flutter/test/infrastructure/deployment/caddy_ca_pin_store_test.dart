import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/deployment/caddy_ca_pin.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/caddy_ca_pin_store.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('writes, reads, and clears a deployment CA pin', () async {
    const storage = FlutterSecureStorage();
    const store = CaddyCaPinStore(storage);
    const pin = CaddyCaPin(
      fingerprint: 'SHA256:abc123',
      certificatePem:
          '-----BEGIN CERTIFICATE-----\nCA\n-----END CERTIFICATE-----',
    );

    await store.write(deploymentId: 'deployment-1', pin: pin);
    expect(await store.read(deploymentId: 'deployment-1'), isNotNull);
    final read = await store.read(deploymentId: 'deployment-1');
    expect(read!.fingerprint, pin.fingerprint);
    expect(read.certificatePem, pin.certificatePem);

    await store.clear('deployment-1');
    expect(await store.read(deploymentId: 'deployment-1'), isNull);
  });

  test('does not share pins between deployments', () async {
    const storage = FlutterSecureStorage();
    const store = CaddyCaPinStore(storage);
    await store.write(
      deploymentId: 'one',
      pin: const CaddyCaPin(fingerprint: 'SHA256:one', certificatePem: 'one'),
    );

    expect(await store.read(deploymentId: 'two'), isNull);
  });
}
