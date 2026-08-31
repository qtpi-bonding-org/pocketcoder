import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_root_ssh_credentials_provider.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_root_ssh_credentials_store.dart';

class _MockStore extends Mock implements FossRootSshCredentialsStore {}

void main() {
  test('maps a saved record onto the shared RootSshCredentials shape',
      () async {
    final store = _MockStore();
    when(() => store.load())
        .thenAnswer((_) async => const FossRootSshCredentials(
              publicKey: 'PUB',
              privateKey: 'PRIV',
              hostKeyType: 'ssh-ed25519',
              hostKeyFingerprint: 'SHA256:abc',
            ));
    final provider = FossRootSshCredentialsProvider(store);

    final credentials = await provider.readRootSshCredentials(instanceId: '');

    expect(credentials?.privateKeyPem, 'PRIV');
    expect(credentials?.hostKeyType, 'ssh-ed25519');
    expect(credentials?.hostKeyFingerprint, 'SHA256:abc');
  });

  test('returns null when nothing has been saved', () async {
    final store = _MockStore();
    when(() => store.load()).thenAnswer((_) async => null);
    final provider = FossRootSshCredentialsProvider(store);

    expect(await provider.readRootSshCredentials(instanceId: ''), isNull);
  });
}
