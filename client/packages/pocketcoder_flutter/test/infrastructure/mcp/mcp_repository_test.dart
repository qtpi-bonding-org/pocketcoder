import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';
import 'package:pocketcoder_flutter/infrastructure/mcp/mcp_daos.dart';
import 'package:pocketcoder_flutter/infrastructure/mcp/mcp_repository.dart';

import '../../helpers/capturing_dio_adapter.dart';

class MockMcpServerDao extends Mock implements McpServerDao {}

class _FakeMcpServer extends Fake implements McpServer {}

void main() {
  late McpRepository repo;
  late MockMcpServerDao dao;
  late CapturingDioAdapter adapter;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    dao = MockMcpServerDao();
    adapter = CapturingDioAdapter(
      (_, __) => jsonResponse({'stored': true}),
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://pb.local'))
      ..httpClientAdapter = adapter;
    repo = McpRepository(dao, PocketCoderApiClient(dio: dio));
  });

  group('McpRepository.createServer', () {
    test(
        'creates an mcp_servers row with status approved via dao.save(null, ...)',
        () async {
      when(() => dao.save(any(), any()))
          .thenAnswer((_) async => _FakeMcpServer());

      await repo.createServer(
          name: 'hello-world', image: 'mcp/hello-world:latest');

      verify(() => dao.save(null, {
            'name': 'hello-world',
            'status': 'approved',
            'image': 'mcp/hello-world:latest',
          })).called(1);
    });

    test('omits image/config keys entirely when not provided', () async {
      when(() => dao.save(any(), any()))
          .thenAnswer((_) async => _FakeMcpServer());

      await repo.createServer(name: 'hello-world');

      verify(() => dao.save(null, {
            'name': 'hello-world',
            'status': 'approved',
          })).called(1);
    });

    test('passes oauth_provider/oauth_token_env_var through when provided',
        () async {
      when(() => dao.save(any(), any()))
          .thenAnswer((_) async => _FakeMcpServer());

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
    test('POSTs server_name/access_token/refresh_token to mcpOAuthStore',
        () async {
      await repo.deliverOAuthToken('github-mcp-server',
          accessToken: 'tok', refreshToken: 'ref');

      expect(adapter.lastRequest?.path, '/api/pocketcoder/v1/mcp/oauth/store');
      expect(adapter.lastJsonBody, {
        'server_name': 'github-mcp-server',
        'access_token': 'tok',
        'refresh_token': 'ref',
      });
    });

    test('omits refresh_token when null', () async {
      await repo.deliverOAuthToken('github-mcp-server', accessToken: 'tok');

      expect(adapter.lastJsonBody, {
        'server_name': 'github-mcp-server',
        'access_token': 'tok',
      });
    });

    test('wraps failures in McpException', () async {
      adapter.responder = (_, __) => jsonResponse(
            {'message': 'boom'},
            statusCode: 500,
          );

      await expectLater(
        () => repo.deliverOAuthToken('github-mcp-server', accessToken: 'tok'),
        throwsA(isA<McpException>()),
      );
    });
  });
}
