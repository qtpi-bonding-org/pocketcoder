import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart';
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_repository.dart';

class MockMcpRepository extends Mock implements IMcpRepository {}

void main() {
  late MockMcpRepository repo;
  McpCubit? lastCubit;

  McpCubit buildCubit() {
    final cubit = McpCubit(repo);
    lastCubit = cubit;
    return cubit;
  }

  setUp(() {
    repo = MockMcpRepository();
  });

  tearDown(() async {
    if (lastCubit != null) {
      await lastCubit!.close();
      lastCubit = null;
    }
  });

  group('McpCubit.createServer', () {
    test('calls repository.createServer with the given fields', () async {
      when(() => repo.createServer(
            name: any(named: 'name'),
            image: any(named: 'image'),
            config: any(named: 'config'),
          )).thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.createServer(name: 'hello-world', image: 'mcp/hello-world:latest');

      verify(() => repo.createServer(
            name: 'hello-world',
            image: 'mcp/hello-world:latest',
            config: null,
          )).called(1);
    });

    test('emits error state on repository failure', () async {
      when(() => repo.createServer(
            name: any(named: 'name'),
            image: any(named: 'image'),
            config: any(named: 'config'),
          )).thenThrow(Exception('boom'));

      final cubit = buildCubit();
      await cubit.createServer(name: 'hello-world');

      expect(cubit.state.hasError, isTrue);
    });
  });
}