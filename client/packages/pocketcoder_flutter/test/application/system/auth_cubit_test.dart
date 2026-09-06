import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/domain/billing/billing_service.dart';
import 'package:pocketcoder_flutter/domain/deployment/i_server_readiness_check.dart';
import 'package:pocketcoder_flutter/domain/system/factory_reset_hook.dart';
import 'package:pocketcoder_flutter/domain/system/pro_data_deletion_hook.dart';
import 'package:pocketcoder_flutter/infrastructure/deployment/caddy_ca_pin_store.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

class MockBillingService extends Mock implements BillingService {}

// CaddyCaPinStore is a `final class`, so it can't be mocked directly from
// this test library -- build a real instance over a mocked
// FlutterSecureStorage instead (FlutterSecureStorage isn't final).
class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class MockFactoryResetHook extends Mock implements FactoryResetHook {}

class MockProDataDeletionHook extends Mock implements ProDataDeletionHook {}

class MockServerReadinessCheck extends Mock implements IServerReadinessCheck {}

void main() {
  late MockAuthRepository repo;
  late MockFlutterSecureStorage secureStorage;
  late MockFactoryResetHook factoryResetHook;
  late MockProDataDeletionHook proDataDeletionHook;
  late MockBillingService billingService;
  late MockServerReadinessCheck serverReadinessCheck;
  AuthCubit? lastCubit;

  AuthCubit buildCubit() {
    final cubit = AuthCubit(
      repo,
      CaddyCaPinStore(secureStorage),
      factoryResetHook,
      proDataDeletionHook,
      billingService,
      serverReadinessCheck,
    );
    lastCubit = cubit;
    return cubit;
  }

  setUp(() {
    repo = MockAuthRepository();
    secureStorage = MockFlutterSecureStorage();
    factoryResetHook = MockFactoryResetHook();
    proDataDeletionHook = MockProDataDeletionHook();
    billingService = MockBillingService();
    serverReadinessCheck = MockServerReadinessCheck();
    when(() => billingService.reset()).thenAnswer((_) async {});
    when(() => serverReadinessCheck.retry()).thenAnswer((_) async {});
    when(() => secureStorage.readAll(
          aOptions: any(named: 'aOptions'),
          iOptions: any(named: 'iOptions'),
          lOptions: any(named: 'lOptions'),
          webOptions: any(named: 'webOptions'),
          mOptions: any(named: 'mOptions'),
          wOptions: any(named: 'wOptions'),
        )).thenAnswer((_) async => {});
    when(() => factoryResetHook.resetForFactoryReset())
        .thenAnswer((_) async {});
  });

  tearDown(() async {
    if (lastCubit != null) {
      await lastCubit!.close();
      lastCubit = null;
    }
  });

  group('AuthCubit.logout', () {
    test('calls repository.logout() and emits success', () async {
      when(() => repo.logout()).thenAnswer((_) async {});
      final cubit = buildCubit();

      await cubit.logout();

      verify(() => repo.logout()).called(1);
      expect(cubit.state.status, UiFlowStatus.success);
      expect(cubit.state.error, isNull);
    });

    test('emits failure when repository.logout() throws', () async {
      when(() => repo.logout()).thenThrow(Exception('storage write failed'));
      final cubit = buildCubit();

      await cubit.logout();

      expect(cubit.state.status, UiFlowStatus.failure);
      expect(cubit.state.error, isNotNull);
    });
  });

  group('AuthCubit.login', () {
    test(
        'checks compatibility before sending credentials, persists the '
        'URL only after a successful login', () async {
      when(() => repo.updateBaseUrl('https://server.example'))
          .thenAnswer((_) async {});
      when(() => repo.verifyServerCompatibility()).thenAnswer((_) async {});
      when(() => repo.login('owner@example.com', 'secret'))
          .thenAnswer((_) async => true);
      when(() => repo.persistBaseUrl('https://server.example'))
          .thenAnswer((_) async {});
      when(() => repo.getSavedBaseUrl())
          .thenAnswer((_) async => 'https://old-good-server.example');
      final cubit = buildCubit();

      await cubit.login(
        'https://server.example',
        'owner@example.com',
        'secret',
      );

      verifyInOrder([
        () => repo.updateBaseUrl('https://server.example'),
        () => repo.verifyServerCompatibility(),
        () => repo.login('owner@example.com', 'secret'),
        () => repo.persistBaseUrl('https://server.example'),
      ]);
      expect(cubit.state.status, UiFlowStatus.success);
    });

    test(
        'does not send credentials to an incompatible server, and never '
        'persists the unverified URL', () async {
      when(() => repo.updateBaseUrl('https://server.example'))
          .thenAnswer((_) async {});
      when(() => repo.verifyServerCompatibility())
          .thenThrow(Exception('incompatible server'));
      when(() => repo.getSavedBaseUrl())
          .thenAnswer((_) async => 'https://old-good-server.example');
      when(() => repo.updateBaseUrl('https://old-good-server.example'))
          .thenAnswer((_) async {});
      final cubit = buildCubit();

      await cubit.login(
        'https://server.example',
        'owner@example.com',
        'secret',
      );

      verifyNever(() => repo.login(any(), any()));
      verifyNever(() => repo.persistBaseUrl(any()));
      expect(cubit.state.status, UiFlowStatus.failure);
      expect(cubit.state.error.toString(), contains('incompatible server'),
          reason: 'the original failure reason must survive the revert');
    });

    test(
        'a wrong-credentials failure against a typo\'d URL never persists '
        'it, and reverts the in-memory URL back to the last known good one '
        '-- one bad URL must not permanently strand the user away from '
        'their real, working deployment', () async {
      when(() => repo.updateBaseUrl(any())).thenAnswer((_) async {});
      when(() => repo.verifyServerCompatibility()).thenAnswer((_) async {});
      when(() => repo.login('owner@example.com', 'wrong-password'))
          .thenAnswer((_) async => false);
      when(() => repo.getSavedBaseUrl())
          .thenAnswer((_) async => 'https://old-good-server.example');
      final cubit = buildCubit();

      await cubit.login(
        'https://typo-server.example',
        'owner@example.com',
        'wrong-password',
      );

      verifyNever(() => repo.persistBaseUrl(any()));
      verify(() => repo.updateBaseUrl('https://old-good-server.example'))
          .called(1);
      expect(cubit.state.status, UiFlowStatus.failure);
    });
  });

  group('AuthCubit.factoryReset', () {
    test(
        'clears the auth session, every stored CA pin, the '
        'app-specific hook, and the billing identity, and emits success',
        () async {
      when(() => repo.clearSession()).thenAnswer((_) async {});
      when(() => secureStorage.readAll(
            aOptions: any(named: 'aOptions'),
            iOptions: any(named: 'iOptions'),
            lOptions: any(named: 'lOptions'),
            webOptions: any(named: 'webOptions'),
            mOptions: any(named: 'mOptions'),
            wOptions: any(named: 'wOptions'),
          )).thenAnswer((_) async => {
            'pocketcoder.caddy-ca-pin.instance-1': 'stale-pin-json',
            'unrelated.other.key': 'untouched',
          });
      when(() => secureStorage.delete(
            key: any(named: 'key'),
            aOptions: any(named: 'aOptions'),
            iOptions: any(named: 'iOptions'),
            lOptions: any(named: 'lOptions'),
            webOptions: any(named: 'webOptions'),
            mOptions: any(named: 'mOptions'),
            wOptions: any(named: 'wOptions'),
          )).thenAnswer((_) async {});
      final cubit = buildCubit();

      await cubit.factoryReset();

      verify(() => repo.clearSession()).called(1);
      verify(() => secureStorage.delete(
            key: 'pocketcoder.caddy-ca-pin.instance-1',
            aOptions: any(named: 'aOptions'),
            iOptions: any(named: 'iOptions'),
            lOptions: any(named: 'lOptions'),
            webOptions: any(named: 'webOptions'),
            mOptions: any(named: 'mOptions'),
            wOptions: any(named: 'wOptions'),
          )).called(1);
      verifyNever(() => secureStorage.delete(
            key: 'unrelated.other.key',
            aOptions: any(named: 'aOptions'),
            iOptions: any(named: 'iOptions'),
            lOptions: any(named: 'lOptions'),
            webOptions: any(named: 'webOptions'),
            mOptions: any(named: 'mOptions'),
            wOptions: any(named: 'wOptions'),
          ));
      verify(() => factoryResetHook.resetForFactoryReset()).called(1);
      verify(() => billingService.reset()).called(1);
      expect(cubit.state.status, UiFlowStatus.success);
    });

    test(
        'clears deployment-identity state and re-checks readiness before '
        'clearing the session -- a boot-routing listener reacting to '
        'clearSession() must see the post-reset state, not a stale '
        'pre-reset readiness snapshot', () async {
      when(() => repo.clearSession()).thenAnswer((_) async {});
      when(() => secureStorage.readAll(
            aOptions: any(named: 'aOptions'),
            iOptions: any(named: 'iOptions'),
            lOptions: any(named: 'lOptions'),
            webOptions: any(named: 'webOptions'),
            mOptions: any(named: 'mOptions'),
            wOptions: any(named: 'wOptions'),
          )).thenAnswer((_) async => {});
      final cubit = buildCubit();

      await cubit.factoryReset();

      verifyInOrder([
        () => factoryResetHook.resetForFactoryReset(),
        () => serverReadinessCheck.retry(),
        () => repo.clearSession(),
      ]);
    });
  });

  group('AuthCubit.deleteProData', () {
    test('calls the hook and emits success, without touching the session',
        () async {
      when(() => proDataDeletionHook.deleteProData()).thenAnswer((_) async {});
      final cubit = buildCubit();

      await cubit.deleteProData();

      verify(() => proDataDeletionHook.deleteProData()).called(1);
      verifyNever(() => repo.clearSession());
      verifyNever(() => repo.logout());
      expect(cubit.state.status, UiFlowStatus.success);
      expect(cubit.state.skipOnboardingNavigation, isTrue,
          reason: 'unlike logout/factoryReset, this must not send the '
              'user to onboarding -- the session is untouched');
    });

    test('emits failure when the hook throws', () async {
      when(() => proDataDeletionHook.deleteProData())
          .thenThrow(Exception('relay unreachable'));
      final cubit = buildCubit();

      await cubit.deleteProData();

      expect(cubit.state.status, UiFlowStatus.failure);
    });
  });
}
