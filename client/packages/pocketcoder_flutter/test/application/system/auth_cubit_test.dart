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
}
