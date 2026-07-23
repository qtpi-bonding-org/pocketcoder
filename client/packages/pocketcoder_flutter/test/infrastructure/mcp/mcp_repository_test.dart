import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:pocketcoder_flutter/infrastructure/mcp/mcp_daos.dart';
import 'package:pocketcoder_flutter/infrastructure/mcp/mcp_repository.dart';

class MockMcpServerDao extends Mock implements McpServerDao {}

class _FakeMcpServer extends Fake implements McpServer {}

void main() {
  late McpRepository repo;
  late MockMcpServerDao dao;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    dao = MockMcpServerDao();
    repo = McpRepository(dao);
  });

  group('McpRepository.createServer', () {
    test('creates an mcp_servers row with status approved via dao.save(null, ...)',
        () async {
      when(() => dao.save(any(), any())).thenAnswer((_) async => _FakeMcpServer());

      await repo.createServer(name: 'hello-world', image: 'mcp/hello-world:latest');

      verify(() => dao.save(null, {
            'name': 'hello-world',
            'status': 'approved',
            'image': 'mcp/hello-world:latest',
          })).called(1);
    });

    test('omits image/config keys entirely when not provided', () async {
      when(() => dao.save(any(), any())).thenAnswer((_) async => _FakeMcpServer());

      await repo.createServer(name: 'hello-world');

      verify(() => dao.save(null, {
            'name': 'hello-world',
            'status': 'approved',
          })).called(1);
    });

    test('wraps failures in McpException', () async {
      when(() => dao.save(any(), any())).thenThrow(Exception('boom'));

      await expectLater(
        () => repo.createServer(name: 'hello-world'),
        throwsA(isA<McpException>()),
      );
    });
  });
}