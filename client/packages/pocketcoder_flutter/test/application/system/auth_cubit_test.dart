import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late MockAuthRepository repo;
  AuthCubit? lastCubit;

  AuthCubit buildCubit() {
    final cubit = AuthCubit(repo);
    lastCubit = cubit;
    return cubit;
  }

  setUp(() {
    repo = MockAuthRepository();
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
    test('checks compatibility before sending credentials, persists the '
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

    test('does not send credentials to an incompatible server, and never '
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
}
