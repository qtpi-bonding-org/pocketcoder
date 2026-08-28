import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/harness_auth/harness_auth_cubit.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/harness_auth_models.dart';
import 'package:pocketcoder_flutter/domain/harness_auth/i_harness_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/models/harness_provider.dart';
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

  setUp(() async {
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
    when(() => providerRepository.watchHarnesses())
        .thenAnswer((_) => const Stream.empty());
    when(() => providerRepository.watchHarnessProviders()).thenAnswer((_) => Stream.value([
          const HarnessProvider(
            id: 'edge-1',
            harness: 'harness-1',
            provider: 'provider-1',
            supportsOauth: true,
          ),
        ]));
    cubit = HarnessAuthCubit(
      providerRepository: providerRepository,
      authRepository: authRepository,
    )..watchData();
    await pumpEventQueue();
  });

  tearDown(() => cubit.close());

  test(
      'startWithNone with an explicit provider bypasses '
      '_oauthProviderFor entirely -- required for multi-provider harnesses '
      '(Goose, OpenCode), which never have a single oauth-capable edge',
      () async {
    when(() => authRepository.start(
          harnessId: 'goose-1',
          provider: 'provider-anthropic',
          mode: 'none',
          visibility: harnessAccountVisibilityPersonal,
        )).thenAnswer((_) async => const HarnessAuthStatus(
          harness: 'goose-1',
          provider: 'provider-anthropic',
          accountId: '',
          accountName: '',
          visibility: harnessAccountVisibilityPersonal,
          credentialMode: 'none',
          status: 'disconnected',
        ));

    // 'goose-1' has no harness_providers edge at all in this cubit's state
    // (only 'harness-1'/'provider-1' does, seeded in setUp), so
    // _oauthProviderFor('goose-1') resolves to null -- proving the explicit
    // provider argument, not a lucky fallback, is what drives the call.
    await cubit.startWithNone('goose-1',
        provider: 'provider-anthropic',
        visibility: harnessAccountVisibilityPersonal);

    verify(() => authRepository.start(
          harnessId: 'goose-1',
          provider: 'provider-anthropic',
          mode: 'none',
          visibility: harnessAccountVisibilityPersonal,
        )).called(1);
    expect(
        cubit.state.statusFor('goose-1', 'provider-anthropic')?.status,
        'disconnected');
  });

  test(
      'startWithNone with no explicit provider and no oauth-capable edge '
      'silently no-ops, same as before -- the explicit-provider path above '
      'is what fixes multi-provider harnesses, not a change to this default',
      () async {
    await cubit.startWithNone('goose-1',
        visibility: harnessAccountVisibilityPersonal);

    verifyNever(() => authRepository.start(
          harnessId: any(named: 'harnessId'),
          provider: any(named: 'provider'),
          mode: any(named: 'mode'),
          visibility: any(named: 'visibility'),
        ));
  });

  test('captures a direct harness operation exactly once', () async {
    when(() => authRepository.start(
          harnessId: 'harness-1',
          provider: 'provider-1',
          mode: 'none',
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
