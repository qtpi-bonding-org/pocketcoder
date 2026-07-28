import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:pocketcoder_flutter/infrastructure/mcp/mcp_daos.dart';
import 'package:pocketcoder_flutter/infrastructure/mcp/mcp_repository.dart';
import 'package:pocketbase/pocketbase.dart';

class MockMcpServerDao extends Mock implements McpServerDao {}

class MockPocketBase extends Mock implements PocketBase {}

class _FakeMcpServer extends Fake implements McpServer {}

void main() {
  late McpRepository repo;
  late MockMcpServerDao dao;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(<String, String>{});
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

    test('passes oauth_provider/oauth_token_env_var through when provided', () async {
      when(() => dao.save(any(), any())).thenAnswer((_) async => _FakeMcpServer());

      await repo.createServer(
        name: 'github-mcp-server',
        oauthProvider: 'github',
        oauthTokenEnvVar: 'GITHUB_PERSONAL_ACCESS_TOKEN',
      );

      verify(() => dao.save(null, {
            'name': 'github-mcp-server',
            'status': 'approved',
            'oauth_provider': 'github',
            'oauth_token_env_var': 'GITHUB_PERSONAL_ACCESS_TOKEN',
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

  group('McpRepository.deliverOAuthToken', () {
    late MockPocketBase pb;

    setUp(() {
      pb = MockPocketBase();
      when(() => dao.pb).thenReturn(pb);
    });

    test('POSTs server_name/access_token/refresh_token to mcpOAuthStore', () async {
      when(() => pb.send<dynamic>(any(), method: any(named: 'method'), body: any(named: 'body')))
          .thenAnswer((_) async => {'stored': true});

      await repo.deliverOAuthToken('github-mcp-server', accessToken: 'tok', refreshToken: 'ref');

      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/mcp_oauth/store',
            method: 'POST',
            body: {
              'server_name': 'github-mcp-server',
              'access_token': 'tok',
              'refresh_token': 'ref',
            },
          )).called(1);
    });

    test('omits refresh_token when null', () async {
      when(() => pb.send<dynamic>(any(), method: any(named: 'method'), body: any(named: 'body')))
          .thenAnswer((_) async => {'stored': true});

      await repo.deliverOAuthToken('github-mcp-server', accessToken: 'tok');

      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/mcp_oauth/store',
            method: 'POST',
            body: {'server_name': 'github-mcp-server', 'access_token': 'tok'},
          )).called(1);
    });

    test('wraps failures in McpException', () async {
      when(() => pb.send<dynamic>(any(), method: any(named: 'method'), body: any(named: 'body')))
          .thenThrow(Exception('boom'));

      await expectLater(
        () => repo.deliverOAuthToken('github-mcp-server', accessToken: 'tok'),
        throwsA(isA<McpException>()),
      );
    });
  });
}