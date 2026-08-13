import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_cubit.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/i_harness_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';

class _MockStorage extends Mock implements ErrorBoxStorage {}

class _MockProviderRepository extends Mock implements IProviderRepository {}

class _MockAuthRepository extends Mock implements IHarnessAuthRepository {}

void main() {
  late _MockStorage storage;
  late _MockProviderRepository providerRepository;
  late _MockAuthRepository authRepository;
  late HarnessAuthCubit cubit;

  setUpAll(() {
    registerFallbackValue(
      ErrorEntry(
        source: 'fallback',
        errorType: 'fallback',
        errorCode: 'fallback',
        stackTrace: 'fallback',
        timestamp: DateTime(2026),
      ),
    );
  });

  setUp(() {
    storage = _MockStorage();
    providerRepository = _MockProviderRepository();
    authRepository = _MockAuthRepository();
    when(() => storage.saveError(any())).thenAnswer((_) async {});
    ErrorPrivserver.configure(ErrorPrivserverConfig(
      storage: storage,
      reporter: (_) async => false,
      errorCodeMapper: (_) => 'ERR_TEST',
      exceptionMapper: (_) => null,
    ));
    cubit = HarnessAuthCubit(
      providerRepository: providerRepository,
      authRepository: authRepository,
    );
  });

  tearDown(() => cubit.close());

  test('captures a direct harness operation exactly once', () async {
    when(() => authRepository.start(
          harnessId: 'harness-1',
          credentialMode: 'none',
          visibility: harnessAccountVisibilityPersonal,
        )).thenThrow(StateError('not persisted'));

    await cubit.startWithNone('harness-1',
        visibility: harnessAccountVisibilityPersonal);

    expect(cubit.state.error, isA<StateError>());
    final entries = verify(() => storage.saveError(captureAny())).captured;
    expect(entries, hasLength(1));
    expect((entries.single as ErrorEntry).source,
        'HarnessAuthCubit.harnessOperation');
  });
}
