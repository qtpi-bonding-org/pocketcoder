import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_oauth_service.dart';
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_repository.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';

class MockMcpRepository extends Mock implements IMcpRepository {}

class MockMcpOAuthService extends Mock implements IMcpOAuthService {}

void main() {
  late MockMcpRepository repo;
  late MockMcpOAuthService oauthService;
  McpCubit? lastCubit;

  McpCubit buildCubit() {
    final cubit = McpCubit(repo, oauthService);
    lastCubit = cubit;
    return cubit;
  }

  setUp(() {
    repo = MockMcpRepository();
    oauthService = MockMcpOAuthService();
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
            oauthProvider: any(named: 'oauthProvider'),
            oauthTokenEnvVar: any(named: 'oauthTokenEnvVar'),
          )).thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.createServer(
          name: 'hello-world', image: 'mcp/hello-world:latest');

      verify(() => repo.createServer(
            name: 'hello-world',
            image: 'mcp/hello-world:latest',
            config: null,
            oauthProvider: null,
            oauthTokenEnvVar: null,
          )).called(1);
    });

    test('emits error state on repository failure', () async {
      when(() => repo.createServer(
            name: any(named: 'name'),
            image: any(named: 'image'),
            config: any(named: 'config'),
            oauthProvider: any(named: 'oauthProvider'),
            oauthTokenEnvVar: any(named: 'oauthTokenEnvVar'),
          )).thenThrow(Exception('boom'));

      final cubit = buildCubit();
      await cubit.createServer(name: 'hello-world');

      expect(cubit.state.hasError, isTrue);
    });
  });

  McpServer oauthServer({String status = 'approved'}) => McpServer.fromJson({
        'id': 'srv1',
        'name': 'github-mcp-server',
        'status': status,
        'oauth_provider': 'github',
      });

  group('McpCubit.connectOAuth', () {
    test('delivers the token pair to the repository on success', () async {
      when(() => oauthService.authenticate('github'))
          .thenAnswer((_) async => (accessToken: 'tok', refreshToken: 'ref'));
      when(() => repo.deliverOAuthToken(any(),
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'))).thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.connectOAuth(oauthServer());

      verify(() => repo.deliverOAuthToken('github-mcp-server',
          accessToken: 'tok', refreshToken: 'ref')).called(1);
      expect(cubit.hasPendingOAuthDelivery('srv1'), isFalse);
    });

    test('cancelled auth does not emit an error state', () async {
      when(() => oauthService.authenticate('github'))
          .thenThrow(McpOAuthException.cancelled());

      final cubit = buildCubit();
      await cubit.connectOAuth(oauthServer());

      expect(cubit.state.hasError, isFalse);
    });

    test(
        'delivery failure after retries keeps the token pending for retryOAuthDelivery',
        () async {
      when(() => oauthService.authenticate('github'))
          .thenAnswer((_) async => (accessToken: 'tok', refreshToken: 'ref'));
      when(() => repo.deliverOAuthToken(any(),
              accessToken: any(named: 'accessToken'),
              refreshToken: any(named: 'refreshToken')))
          .thenThrow(Exception('pb unreachable'));

      final cubit = buildCubit();
      await cubit.connectOAuth(oauthServer());

      expect(cubit.state.hasError, isTrue);
      expect(cubit.hasPendingOAuthDelivery('srv1'), isTrue);

      // retryOAuthDelivery re-delivers without calling authenticate again.
      when(() => repo.deliverOAuthToken(any(),
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'))).thenAnswer((_) async {});
      await cubit.retryOAuthDelivery('srv1');

      verify(() => oauthService.authenticate('github'))
          .called(1); // still only once
      expect(cubit.hasPendingOAuthDelivery('srv1'), isFalse);
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  group('McpCubit.supportedOAuthProviders', () {
    test('delegates to IMcpOAuthService.supportedProviders', () async {
      when(() => oauthService.supportedProviders())
          .thenAnswer((_) async => [(id: 'github', displayName: 'GitHub')]);

      final cubit = buildCubit();
      final result = await cubit.supportedOAuthProviders();

      expect(result, [(id: 'github', displayName: 'GitHub')]);
      verify(() => oauthService.supportedProviders()).called(1);
    });
  });
}
