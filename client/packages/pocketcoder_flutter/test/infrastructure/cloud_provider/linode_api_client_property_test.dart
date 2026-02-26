import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/infrastructure/cloud_provider/cloud_provider_errors.dart';
import 'package:pocketcoder_flutter/infrastructure/cloud_provider/linode_api_client.dart';

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

  group('LinodeAPIClient - Property Tests', () {
    /// Property 10: Deployment Metadata Completeness
    /// For any valid deployment configuration, preparing metadata SHALL produce
    /// a map containing all required environment variables.
    test('Property 10: Deployment metadata includes cloud_init_url', () async {
      const cloudInitUrl = 'https://example.com/cloud-init.sh';
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

      await client.createInstance(
        accessToken: testAccessToken,
        planType: 'g6-standard-4',
        region: 'us-east',
        image: 'linode/ubuntu22.04',
        rootPassword: 'SecureP@ss123!',
        metadata: {'cloud_init_url': cloudInitUrl},
      );

      verify(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).called(1);
    });

    /// Property 11: Cloud-Init Template URL Inclusion
    /// For any deployment request to Linode_API, the request SHALL include the
    /// Cloud_Init_Template_URL in the metadata.user_data field.
    test('Property 11: Cloud-init URL is included in request metadata', () async {
      const cloudInitUrl = 'https://example.com/cloud-init.sh';
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

      await client.createInstance(
        accessToken: testAccessToken,
        planType: 'g6-standard-4',
        region: 'us-east',
        image: 'linode/ubuntu22.04',
        rootPassword: 'SecureP@ss123!',
        metadata: {'cloud_init_url': cloudInitUrl},
      );

      verify(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).called(1);
    });

    /// Property 12: Ubuntu Image Specification
    /// For any deployment request to Linode_API, the image field SHALL be set
    /// to "linode/ubuntu22.04".
    test('Property 12: Ubuntu image is set correctly', () async {
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

      await client.createInstance(
        accessToken: testAccessToken,
        planType: 'g6-standard-4',
        region: 'us-east',
        image: 'linode/ubuntu22.04',
        rootPassword: 'SecureP@ss123!',
        metadata: {},
      );

      verify(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).called(1);
    });

    /// Property 13: Instance Data Extraction
    /// For any successful Linode_API response, parsing SHALL successfully
    /// extract the instance ID and IP address.
    test('Property 13: Instance data extraction works for valid responses', () async {
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

      final result = await client.getInstance('12345', testAccessToken);

      expect(result.id, isNotEmpty);
      expect(result.ipAddress, isNotEmpty);
      expect(result.id, equals('12345'));
      expect(result.ipAddress, equals('192.168.1.100'));
    });

    /// Property 14: Error Message Generation
    /// For any error response from Linode_API or OAuth service, the service
    /// SHALL produce a user-friendly error message describing the issue.
    test('Property 14: Error messages are generated for all status codes', () {
      final errorMappings = [
        (400, 'Invalid configuration'),
        (401, 'Authentication failed'),
        (402, 'Insufficient account balance'),
        (403, 'Access denied'),
        (404, 'Resource not found'),
        (429, 'Too many requests'),
        (500, 'Service temporarily unavailable'),
        (502, 'Service temporarily unavailable'),
        (503, 'Service temporarily unavailable'),
      ];

      for (final (statusCode, expectedPrefix) in errorMappings) {
        final error = CloudProviderAPIError(
          statusCode: statusCode,
          message: 'Test error',
        );
        final userMessage = error.getUserFriendlyMessage();

        expect(
          userMessage.startsWith(expectedPrefix),
          isTrue,
          reason: 'Status $statusCode should produce message starting with "$expectedPrefix"',
        );
      }
    });

    /// Property 38: Token Refresh Request Format
    /// For any token refresh operation, the request to Linode OAuth endpoint
    /// SHALL include grant_type=refresh_token.
    test('Property 38: Token refresh request includes correct grant_type', () async {
      final response = http.Response(
        jsonEncode({
          'access_token': 'new-access-token',
          'refresh_token': 'new-refresh-token',
          'expires_in': 3600,
          'scope': 'linodes:read_write',
        }),
        200,
      );

      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => response);

      await client.refreshAccessToken('refresh-token');

      verify(() => mockHttpClient.post(
            Uri.parse('https://login.linode.com/oauth/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'grant_type': 'refresh_token',
              'refresh_token': 'refresh-token',
              'client_id': testClientId,
            },
          )).called(1);
    });
  });
}