import 'package:pocketcoder_flutter/domain/security/i_ssh_key_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/application/foss/foss_server_setup_cubit.dart';
import 'package:pocketcoder_flutter/application/foss/foss_server_setup_state.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_root_ssh_connection_tester.dart';
import 'package:pocketcoder_flutter/infrastructure/foss/foss_root_ssh_credentials_store.dart';

class _MockKeyGenerator extends Mock implements ISshKeyGenerator {}

class _MockTester extends Mock implements IFossRootSshConnectionTester {}

class _MockStore extends Mock implements FossRootSshCredentialsStore {}

void main() {
  late _MockKeyGenerator keyGenerator;
  late _MockTester tester;
  late _MockStore store;
  late FossServerSetupCubit cubit;

  setUp(() {
    registerFallbackValue(const FossRootSshCredentials(
      publicKey: 'fallback',
      privateKey: 'fallback',
      hostKeyType: 'fallback',
      hostKeyFingerprint: 'fallback',
    ));
    keyGenerator = _MockKeyGenerator();
    tester = _MockTester();
    store = _MockStore();
    cubit = FossServerSetupCubit(
      keyGenerator,
      tester,
      store,
      PocketBase('https://203.0.113.10'),
    );
  });

  test('host is derived from the PocketBase URL, matching what '
      'SshServerControlService will later connect to', () {
    expect(cubit.host, '203.0.113.10');
  });

  test('generateKey moves to keyReady with the public key visible', () async {
    when(() => keyGenerator.generate()).thenAnswer(
      (_) async => (publicKey: 'ssh-ed25519 AAAA...', privateKey: 'PRIVATE'),
    );

    await cubit.generateKey();

    expect(cubit.state.phase, FossServerSetupPhase.keyReady);
    expect(cubit.state.publicKey, 'ssh-ed25519 AAAA...');
  });

  test('testAndSave tests and saves against the PocketBase-derived host, '
      'not a caller-supplied one, and moves to connected on success',
      () async {
    when(() => keyGenerator.generate()).thenAnswer(
      (_) async => (publicKey: 'PUB', privateKey: 'PRIV'),
    );
    await cubit.generateKey();

    when(() => tester.testConnection(host: '203.0.113.10', privateKeyPem: 'PRIV'))
        .thenAnswer((_) async => const FossHostIdentity(
              hostKeyType: 'ssh-ed25519',
              hostKeyFingerprint: 'SHA256:abc',
            ));
    when(() => store.save(any())).thenAnswer((_) async {});

    await cubit.testAndSave();

    expect(cubit.state.phase, FossServerSetupPhase.connected);
    final saved =
        verify(() => store.save(captureAny())).captured.single as FossRootSshCredentials;
    expect(saved.publicKey, 'PUB');
    expect(saved.privateKey, 'PRIV');
    expect(saved.hostKeyType, 'ssh-ed25519');
    expect(saved.hostKeyFingerprint, 'SHA256:abc');
  });

  test('testAndSave surfaces a connection failure without saving anything',
      () async {
    when(() => keyGenerator.generate()).thenAnswer(
      (_) async => (publicKey: 'PUB', privateKey: 'PRIV'),
    );
    await cubit.generateKey();

    when(() => tester.testConnection(
          host: any(named: 'host'),
          privateKeyPem: any(named: 'privateKeyPem'),
        )).thenThrow(Exception('connection refused'));

    await cubit.testAndSave();

    expect(cubit.state.phase, FossServerSetupPhase.keyReady);
    expect(cubit.state.error, isNotNull);
    verifyNever(() => store.save(any()));
  });

  test('testAndSave is a no-op once already connected -- the TOFU pin is '
      'never silently re-established after the fact', () async {
    when(() => keyGenerator.generate()).thenAnswer(
      (_) async => (publicKey: 'PUB', privateKey: 'PRIV'),
    );
    await cubit.generateKey();
    when(() => tester.testConnection(host: any(named: 'host'), privateKeyPem: any(named: 'privateKeyPem')))
        .thenAnswer((_) async => const FossHostIdentity(
              hostKeyType: 'ssh-ed25519',
              hostKeyFingerprint: 'SHA256:abc',
            ));
    when(() => store.save(any())).thenAnswer((_) async {});
    await cubit.testAndSave();
    clearInteractions(tester);
    clearInteractions(store);

    await cubit.testAndSave();

    verifyNever(() => tester.testConnection(
        host: any(named: 'host'), privateKeyPem: any(named: 'privateKeyPem')));
    verifyNever(() => store.save(any()));
  });
}
