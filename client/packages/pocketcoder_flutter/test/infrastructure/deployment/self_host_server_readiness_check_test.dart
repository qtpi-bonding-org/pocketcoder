import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_server_readiness_check.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/self_host_server_readiness_check.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late MockAuthRepository authRepository;

  setUp(() {
    authRepository = MockAuthRepository();
  });

  test('no saved URL is notProvisioned', () async {
    when(() => authRepository.getSavedBaseUrl()).thenAnswer((_) async => null);
    final check = SelfHostServerReadinessCheck(authRepository: authRepository);
    await check.initialize();
    expect(check.current.status, ServerReadinessStatus.notProvisioned);
  });

  test(
      'a saved URL is ready -- only the local secure-storage read happens, no '
      'reachability probe (there is none in this implementation; see step 2)',
      () async {
    when(() => authRepository.getSavedBaseUrl())
        .thenAnswer((_) async => 'https://my-server.example');
    final check = SelfHostServerReadinessCheck(authRepository: authRepository);
    await check.initialize();
    expect(check.current.status, ServerReadinessStatus.ready);
    verify(() => authRepository.getSavedBaseUrl()).called(1);
  });

  test('retry() re-reads the saved URL and updates readinessChanges', () async {
    var url = 'https://old.example';
    when(() => authRepository.getSavedBaseUrl()).thenAnswer((_) async => url);
    final check = SelfHostServerReadinessCheck(authRepository: authRepository);
    await check.initialize();
    url = 'https://new.example';
    final emitted = <ServerReadinessSnapshot>[];
    final sub = check.readinessChanges.listen(emitted.add);
    await check.retry();
    expect(emitted.single.status, ServerReadinessStatus.ready);
    await sub.cancel();
  });
}
