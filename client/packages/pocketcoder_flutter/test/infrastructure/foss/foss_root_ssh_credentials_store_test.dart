import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_root_ssh_credentials_store.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockSecureStorage storage;
  late FossRootSshCredentialsStore store;

  const credentials = FossRootSshCredentials(
    publicKey: 'ssh-ed25519 AAAA... pocketcoder',
    privateKey: '-----BEGIN OPENSSH PRIVATE KEY-----\n...',
    hostKeyType: 'ssh-ed25519',
    hostKeyFingerprint: 'SHA256:abc123',
  );

  setUp(() {
    storage = _MockSecureStorage();
    store = FossRootSshCredentialsStore(storage);
  });

  test('save writes one serialized value under a single key', () async {
    String? written;
    when(() => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((invocation) async {
      written = invocation.namedArguments[#value] as String;
    });

    await store.save(credentials);

    verify(() => storage.write(
        key: 'foss.root_ssh.credentials',
        value: any(named: 'value'))).called(1);
    when(() => storage.read(key: 'foss.root_ssh.credentials'))
        .thenAnswer((_) async => written);
    expect(await store.load(), credentials);
  });

  test('load returns null when nothing has been saved yet', () async {
    when(() => storage.read(key: 'foss.root_ssh.credentials'))
        .thenAnswer((_) async => null);

    expect(await store.load(), isNull);
  });

  test(
      'load returns null for a corrupted/partial stored value rather than '
      'throwing', () async {
    when(() => storage.read(key: 'foss.root_ssh.credentials'))
        .thenAnswer((_) async => 'not valid json');

    expect(await store.load(), isNull);
  });

  test('clear deletes the single key', () async {
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});

    await store.clear();

    verify(() => storage.delete(key: 'foss.root_ssh.credentials')).called(1);
  });
}
