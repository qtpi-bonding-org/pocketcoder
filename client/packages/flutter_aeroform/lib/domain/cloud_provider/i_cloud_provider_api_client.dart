import 'package:flutter_aeroform/domain/models/cloud_provider.dart';
import 'package:flutter_aeroform/domain/models/oauth_token.dart';

/// Abstract interface for cloud provider API operations
abstract class ICloudProviderAPIClient {
  /// Creates a new instance
  Future<CloudInstance> createInstance({
    required String accessToken,
    required String planType,
    required String region,
    required String image,
    required String rootPassword,
    required Map<String, String> metadata,
  });

  /// Gets instance details by ID
  Future<CloudInstance> getInstance(String instanceId, String accessToken);

  /// Lists instances with optional label filter
  Future<List<CloudInstance>> listInstances(
    String accessToken, {
    String? labelFilter,
  });

  /// Exchanges OAuth authorization code for tokens
  Future<OAuthToken> exchangeAuthCode(String code, String codeVerifier);

  /// Refreshes OAuth access token
  Future<OAuthToken> refreshAccessToken(String refreshToken);

  /// Returns the provider name (e.g., "linode", "digitalocean")
  String get providerName;

  /// Returns available plans for this provider
  Future<List<InstancePlan>> getAvailablePlans(String accessToken);

  /// Returns available regions for this provider
  Future<List<Region>> getAvailableRegions(String accessToken);
}