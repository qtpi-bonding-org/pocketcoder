import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/cloud_provider/i_cloud_provider_api_client.dart';
import 'package:pocketcoder_flutter/domain/models/cloud_provider.dart';
import 'package:pocketcoder_flutter/domain/models/oauth_token.dart';
import 'package:pocketcoder_flutter/infrastructure/cloud_provider/cloud_provider_errors.dart';

/// Linode API client implementation for cloud provider operations
@LazySingleton(as: ICloudProviderAPIClient)
class LinodeAPIClient implements ICloudProviderAPIClient {
  static const String _baseUrl = 'https://api.linode.com/v4';
  static const String _oauthUrl = 'https://login.linode.com/oauth';
  static const String _defaultImage = 'linode/ubuntu22.04';

  final http.Client _httpClient;
  final String _clientId;

  LinodeAPIClient(this._httpClient, @Named('linodeClientId') this._clientId);

  @override
  String get providerName => 'linode';

  @override
  Future<CloudInstance> createInstance({
    required String accessToken,
    required String planType,
    required String region,
    required String image,
    required String rootPassword,
    required Map<String, String> metadata,
  }) async {
    final label = 'pocketcoder-${DateTime.now().millisecondsSinceEpoch}';

    final response = await _httpClient.post(
      Uri.parse('$_baseUrl/linode/instances'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'type': planType,
        'region': region,
        'image': image.isNotEmpty ? image : _defaultImage,
        'root_pass': rootPassword,
        'label': label,
        'metadata': {
          'user_data': metadata['cloud_init_url'] ?? '',
          ...metadata,
        },
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw CloudProviderAPIError.fromResponse(response);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseInstanceResponse(json);
  }

  @override
  Future<CloudInstance> getInstance(String instanceId, String accessToken) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/linode/instances/$instanceId'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw CloudProviderAPIError.fromResponse(response);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseInstanceResponse(json);
  }

  @override
  Future<List<CloudInstance>> listInstances(
    String accessToken, {
    String? labelFilter,
  }) async {
    final uri = Uri.parse('$_baseUrl/linode/instances');
    if (labelFilter != null) {
      uri.replace(queryParameters: {'label': labelFilter});
    }

    final response = await _httpClient.get(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw CloudProviderAPIError.fromResponse(response);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as List;

    return data.map((item) => _parseInstanceResponse(item)).toList();
  }

  @override
  Future<OAuthToken> exchangeAuthCode(String code, String codeVerifier) async {
    final response = await _httpClient.post(
      Uri.parse('$_oauthUrl/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'code_verifier': codeVerifier,
        'client_id': _clientId,
        'redirect_uri': 'pocketcoder://oauth-callback',
      },
    );

    if (response.statusCode != 200) {
      throw OAuthError.fromResponse(response);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseOAuthTokenResponse(json);
  }

  @override
  Future<OAuthToken> refreshAccessToken(String refreshToken) async {
    final response = await _httpClient.post(
      Uri.parse('$_oauthUrl/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': _clientId,
      },
    );

    if (response.statusCode != 200) {
      throw OAuthError.fromResponse(response);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseOAuthTokenResponse(json);
  }

  @override
  Future<List<InstancePlan>> getAvailablePlans(String accessToken) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/linode/types'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw CloudProviderAPIError.fromResponse(response);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as List;

    return data.map((item) {
      final memory = item['memory'] as int? ?? 0;
      return InstancePlan(
        id: item['id'] as String,
        name: item['label'] as String,
        memoryMB: memory,
        vcpus: item['vcpus'] as int? ?? 0,
        diskGB: item['disk'] as int? ?? 0,
        monthlyPriceUSD: (item['price']?['monthly'] as num?)?.toDouble() ?? 0.0,
        recommended: memory >= 4096,
      );
    }).toList();
  }

  @override
  Future<List<Region>> getAvailableRegions(String accessToken) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl/regions'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw CloudProviderAPIError.fromResponse(response);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as List;

    return data.map((item) {
      final regionId = item['id'] as String;
      return Region(
        id: regionId,
        name: item['label'] as String? ?? regionId,
        country: item['country'] as String? ?? 'US',
        city: _extractCityFromRegionId(regionId),
      );
    }).toList();
  }

  CloudInstance _parseInstanceResponse(Map<String, dynamic> json) {
    final ipv4 = json['ipv4'] as List?;
    final ipAddress = ipv4?.isNotEmpty == true ? ipv4![0] as String : '';

    return CloudInstance(
      id: json['id'].toString(),
      label: json['label'] as String,
      ipAddress: ipAddress,
      status: _mapLinodeStatus(json['status'] as String?),
      created: _parseDateTime(json['created']),
      region: json['region'] as String,
      planType: json['type'] as String,
      provider: 'linode',
    );
  }

  OAuthToken _parseOAuthTokenResponse(Map<String, dynamic> json) {
    return OAuthToken(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: DateTime.now().add(
        Duration(seconds: json['expires_in'] as int? ?? 3600),
      ),
      scopes: (json['scope'] as String?)?.split(' ') ?? [],
    );
  }

  CloudInstanceStatus _mapLinodeStatus(String? status) {
    switch (status) {
      case 'provisioning':
        return CloudInstanceStatus.provisioning;
      case 'running':
        return CloudInstanceStatus.running;
      case 'offline':
        return CloudInstanceStatus.offline;
      case 'failed':
        return CloudInstanceStatus.failed;
      case 'stopped':
        return CloudInstanceStatus.offline;
      default:
        return CloudInstanceStatus.creating;
    }
  }

  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  String _extractCityFromRegionId(String regionId) {
    final parts = regionId.split('-');
    if (parts.length >= 2) {
      return parts[0];
    }
    return regionId;
  }
}