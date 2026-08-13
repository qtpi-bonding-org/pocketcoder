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
    test('checks compatibility before sending credentials', () async {
      when(() => repo.updateBaseUrl('https://server.example'))
          .thenAnswer((_) async {});
      when(() => repo.verifyServerCompatibility()).thenAnswer((_) async {});
      when(() => repo.login('owner@example.com', 'secret'))
          .thenAnswer((_) async => true);
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
      ]);
      expect(cubit.state.status, UiFlowStatus.success);
    });

    test('does not send credentials to an incompatible server', () async {
      when(() => repo.updateBaseUrl('https://server.example'))
          .thenAnswer((_) async {});
      when(() => repo.verifyServerCompatibility())
          .thenThrow(Exception('incompatible server'));
      final cubit = buildCubit();

      await cubit.login(
        'https://server.example',
        'owner@example.com',
        'secret',
      );

      verifyNever(() => repo.login(any(), any()));
      expect(cubit.state.status, UiFlowStatus.failure);
    });
  });
}
