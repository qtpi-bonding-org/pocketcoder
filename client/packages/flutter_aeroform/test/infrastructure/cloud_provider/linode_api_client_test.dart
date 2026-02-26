import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:flutter_aeroform/domain/models/cloud_provider.dart';
import 'package:flutter_aeroform/infrastructure/cloud_provider/cloud_provider_errors.dart';
import 'package:flutter_aeroform/infrastructure/cloud_provider/linode_api_client.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient mockHttpClient;
  late LinodeAPIClient client;

  const testClientId = 'test-client-id';
  const testAccessToken = 'test-access-token';

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://api.linode.com/v4/linode/instances'));
    registerFallbackValue(http.Response('{}', 200));
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    client = LinodeAPIClient(mockHttpClient, testClientId);
  });

  group('LinodeAPIClient', () {
    group('providerName', () {
      test('returns linode', () {
        expect(client.providerName, equals('linode'));
      });
    });

    group('createInstance', () {
      const planType = 'g6-standard-4';
      const region = 'us-east';
      const image = 'linode/ubuntu22.04';
      const rootPassword = 'SecureP@ss123!';
      const cloudInitUrl = 'https://example.com/cloud-init.sh';

      test('returns parsed instance on success', () async {
        final response = http.Response(
          jsonEncode({
            'id': 12345,
            'label': 'pocketcoder-123456',
            'status': 'running',
            'ipv4': ['192.168.1.100'],
            'region': 'us-east',
            'type': 'g6-standard-4',
            'created': '2024-01-15T10:30:00Z',
          }),
          201,
        );

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => response);

        final result = await client.createInstance(
          accessToken: testAccessToken,
          planType: planType,
          region: region,
          image: image,
          rootPassword: rootPassword,
          metadata: {'cloud_init_url': cloudInitUrl},
        );

        expect(result.id, equals('12345'));
        expect(result.label, equals('pocketcoder-123456'));
        expect(result.ipAddress, equals('192.168.1.100'));
        expect(result.status, equals(CloudInstanceStatus.running));
        expect(result.region, equals('us-east'));
        expect(result.planType, equals('g6-standard-4'));
        expect(result.provider, equals('linode'));
      });

      test('uses default image when empty', () async {
        final response = http.Response(
          jsonEncode({
            'id': 12345,
            'label': 'pocketcoder-123456',
            'status': 'running',
            'ipv4': ['192.168.1.100'],
            'region': 'us-east',
            'type': 'g6-standard-4',
            'created': '2024-01-15T10:30:00Z',
          }),
          201,
        );

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => response);

        final result = await client.createInstance(
          accessToken: testAccessToken,
          planType: planType,
          region: region,
          image: '',
          rootPassword: rootPassword,
          metadata: {},
        );

        expect(result.id, equals('12345'));
      });

      test('throws CloudProviderAPIError on 400', () async {
        final response = http.Response(
          jsonEncode({
            'errors': ['Invalid region specified', 'Invalid image specified'],
          }),
          400,
        );

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => response);

        expect(
          () => client.createInstance(
            accessToken: testAccessToken,
            planType: planType,
            region: region,
            image: image,
            rootPassword: rootPassword,
            metadata: {},
          ),
          throwsA(isA<CloudProviderAPIError>()),
        );
      });

      test('throws CloudProviderAPIError on 402', () async {
        final response = http.Response(
          jsonEncode({
            'errors': ['Account has reached its concurrent instance limit'],
          }),
          402,
        );

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => response);

        expect(
          () => client.createInstance(
            accessToken: testAccessToken,
            planType: planType,
            region: region,
            image: image,
            rootPassword: rootPassword,
            metadata: {},
          ),
          throwsA(isA<CloudProviderAPIError>()),
        );
      });

      test('throws CloudProviderAPIError on 429', () async {
        final response = http.Response(
          jsonEncode({
            'errors': ['Rate limit exceeded'],
          }),
          429,
        );

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => response);

        expect(
          () => client.createInstance(
            accessToken: testAccessToken,
            planType: planType,
            region: region,
            image: image,
            rootPassword: rootPassword,
            metadata: {},
          ),
          throwsA(isA<CloudProviderAPIError>()),
        );
      });

      test('throws CloudProviderAPIError on 500', () async {
        final response = http.Response(
          jsonEncode({
            'errors': ['Internal server error'],
          }),
          500,
        );

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => response);

        expect(
          () => client.createInstance(
            accessToken: testAccessToken,
            planType: planType,
            region: region,
            image: image,
            rootPassword: rootPassword,
            metadata: {},
          ),
          throwsA(isA<CloudProviderAPIError>()),
        );
      });

      test('throws CloudProviderAPIError on 502', () async {
        final response = http.Response('Bad Gateway', 502);

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => response);

        expect(
          () => client.createInstance(
            accessToken: testAccessToken,
            planType: planType,
            region: region,
            image: image,
            rootPassword: rootPassword,
            metadata: {},
          ),
          throwsA(isA<CloudProviderAPIError>()),
        );
      });

      test('throws CloudProviderAPIError on 503', () async {
        final response = http.Response('Service Unavailable', 503);

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => response);

        expect(
          () => client.createInstance(
            accessToken: testAccessToken,
            planType: planType,
            region: region,
            image: image,
            rootPassword: rootPassword,
            metadata: {},
          ),
          throwsA(isA<CloudProviderAPIError>()),
        );
      });
    });

    group('getInstance', () {
      const instanceId = '12345';

      test('returns parsed instance', () async {
        final response = http.Response(
          jsonEncode({
            'id': 12345,
            'label': 'pocketcoder-123456',
            'status': 'running',
            'ipv4': ['192.168.1.100'],
            'region': 'us-east',
            'type': 'g6-standard-4',
            'created': '2024-01-15T10:30:00Z',
          }),
          200,
        );

        when(() => mockHttpClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => response);

        final result = await client.getInstance(instanceId, testAccessToken);

        expect(result.id, equals('12345'));
        expect(result.label, equals('pocketcoder-123456'));
        expect(result.ipAddress, equals('192.168.1.100'));
        expect(result.status, equals(CloudInstanceStatus.running));
      });

      test('maps status offline correctly', () async {
        final response = http.Response(
          jsonEncode({
            'id': 12345,
            'label': 'pocketcoder-123456',
            'status': 'offline',
            'ipv4': ['192.168.1.100'],
            'region': 'us-east',
            'type': 'g6-standard-4',
            'created': '2024-01-15T10:30:00Z',
          }),
          200,
        );

        when(() => mockHttpClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => response);

        final result = await client.getInstance(instanceId, testAccessToken);
        expect(result.status, equals(CloudInstanceStatus.offline));
      });

      test('maps status provisioning correctly', () async {
        final response = http.Response(
          jsonEncode({
            'id': 12345,
            'label': 'pocketcoder-123456',
            'status': 'provisioning',
            'ipv4': [],
            'region': 'us-east',
            'type': 'g6-standard-4',
            'created': '2024-01-15T10:30:00Z',
          }),
          200,
        );

        when(() => mockHttpClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => response);

        final result = await client.getInstance(instanceId, testAccessToken);
        expect(result.status, equals(CloudInstanceStatus.provisioning));
        expect(result.ipAddress, isEmpty);
      });

      test('throws CloudProviderAPIError on 404', () async {
        final response = http.Response('Not Found', 404);

        when(() => mockHttpClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => response);

        expect(
          () => client.getInstance(instanceId, testAccessToken),
          throwsA(isA<CloudProviderAPIError>()),
        );
      });
    });

    group('listInstances', () {
      test('returns list of instances', () async {
        final response = http.Response(
          jsonEncode({
            'data': [
              {
                'id': 12345,
                'label': 'pocketcoder-123456',
                'status': 'running',
                'ipv4': ['192.168.1.100'],
                'region': 'us-east',
                'type': 'g6-standard-4',
                'created': '2024-01-15T10:30:00Z',
              },
              {
                'id': 67890,
                'label': 'pocketcoder-789012',
                'status': 'provisioning',
                'ipv4': [],
                'region': 'us-west',
                'type': 'g6-standard-2',
                'created': '2024-01-15T11:00:00Z',
              },
            ],
          }),
          200,
        );

        when(() => mockHttpClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => response);

        final result = await client.listInstances(testAccessToken);

        expect(result, hasLength(2));
        expect(result[0].id, equals('12345'));
        expect(result[1].id, equals('67890'));
      });

      test('applies label filter', () async {
        final response = http.Response(
          jsonEncode({
            'data': [
              {
                'id': 12345,
                'label': 'pocketcoder-123456',
                'status': 'running',
                'ipv4': ['192.168.1.100'],
                'region': 'us-east',
                'type': 'g6-standard-4',
                'created': '2024-01-15T10:30:00Z',
              },
            ],
          }),
          200,
        );

        when(() => mockHttpClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => response);

        final result = await client.listInstances(
          testAccessToken,
          labelFilter: 'pocketcoder',
        );

        expect(result, hasLength(1));
      });

      test('returns empty list when no instances', () async {
        final response = http.Response(
          jsonEncode({'data': []}),
          200,
        );

        when(() => mockHttpClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => response);

        final result = await client.listInstances(testAccessToken);
        expect(result, isEmpty);
      });
    });

    group('exchangeAuthCode', () {
      const code = 'auth-code-123';
      const codeVerifier = 'code-verifier-456';

      test('exchanges code for tokens', () async {
        final response = http.Response(
          jsonEncode({
            'access_token': 'new-access-token',
            'refresh_token': 'new-refresh-token',
            'expires_in': 3600,
            'scope': 'linodes:read_write linodes:create',
          }),
          200,
        );

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => response);

        final result = await client.exchangeAuthCode(code, codeVerifier);

        expect(result.accessToken, equals('new-access-token'));
        expect(result.refreshToken, equals('new-refresh-token'));
        expect(result.scopes, equals(['linodes:read_write', 'linodes:create']));
        expect(result.expiresAt.isAfter(DateTime.now()), isTrue);
      });

      test('throws OAuthError on invalid grant', () async {
        final response = http.Response(
          jsonEncode({
            'error': 'invalid_grant',
            'error_description': 'The authorization code has expired',
          }),
          400,
        );

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => response);

        expect(
          () => client.exchangeAuthCode(code, codeVerifier),
          throwsA(isA<OAuthError>()),
        );
      });

      test('throws OAuthError on access denied', () async {
        final response = http.Response(
          jsonEncode({
            'error': 'access_denied',
            'error_description': 'The user denied the request',
          }),
          400,
        );

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => response);

        expect(
          () => client.exchangeAuthCode(code, codeVerifier),
          throwsA(isA<OAuthError>()),
        );
      });
    });

    group('refreshAccessToken', () {
      const refreshToken = 'refresh-token-123';

      test('refreshes token successfully', () async {
        final response = http.Response(
          jsonEncode({
            'access_token': 'new-access-token',
            'refresh_token': 'new-refresh-token',
            'expires_in': 7200,
            'scope': 'linodes:read_write linodes:create',
          }),
          200,
        );

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => response);

        final result = await client.refreshAccessToken(refreshToken);

        expect(result.accessToken, equals('new-access-token'));
        expect(result.refreshToken, equals('new-refresh-token'));
        expect(result.expiresAt.difference(DateTime.now()).inSeconds, greaterThan(7000));
      });

      test('throws OAuthError on invalid refresh token', () async {
        final response = http.Response(
          jsonEncode({
            'error': 'invalid_grant',
            'error_description': 'Refresh token is invalid or expired',
          }),
          400,
        );

        when(() => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => response);

        expect(
          () => client.refreshAccessToken(refreshToken),
          throwsA(isA<OAuthError>()),
        );
      });
    });

    group('getAvailablePlans', () {
      test('returns list of plans', () async {
        final response = http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'g6-standard-1',
                'label': 'Linode 1GB',
                'memory': 1024,
                'vcpus': 1,
                'disk': 25600,
                'price': {'monthly': 5.00},
              },
              {
                'id': 'g6-standard-2',
                'label': 'Linode 2GB',
                'memory': 2048,
                'vcpus': 1,
                'disk': 51200,
                'price': {'monthly': 10.00},
              },
              {
                'id': 'g6-standard-4',
                'label': 'Linode 4GB',
                'memory': 4096,
                'vcpus': 2,
                'disk': 76800,
                'price': {'monthly': 20.00},
              },
            ],
          }),
          200,
        );

        when(() => mockHttpClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => response);

        final result = await client.getAvailablePlans(testAccessToken);

        expect(result, hasLength(3));
        expect(result[0].id, equals('g6-standard-1'));
        expect(result[0].memoryMB, equals(1024));
        expect(result[0].recommended, isFalse);

        expect(result[2].id, equals('g6-standard-4'));
        expect(result[2].memoryMB, equals(4096));
        expect(result[2].recommended, isTrue);
      });
    });

    group('getAvailableRegions', () {
      test('returns list of regions', () async {
        final response = http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'us-east',
                'label': 'Newark, NJ',
                'country': 'US',
              },
              {
                'id': 'us-west',
                'label': 'Fremont, CA',
                'country': 'US',
              },
              {
                'id': 'eu-west',
                'label': 'London, UK',
                'country': 'GB',
              },
            ],
          }),
          200,
        );

        when(() => mockHttpClient.get(
              any(),
              headers: any(named: 'headers'),
            )).thenAnswer((_) async => response);

        final result = await client.getAvailableRegions(testAccessToken);

        expect(result, hasLength(3));
        expect(result[0].id, equals('us-east'));
        expect(result[0].city, equals('us'));
        expect(result[0].country, equals('US'));

        expect(result[2].id, equals('eu-west'));
        expect(result[2].city, equals('eu'));
        expect(result[2].country, equals('GB'));
      });
    });
  });
}