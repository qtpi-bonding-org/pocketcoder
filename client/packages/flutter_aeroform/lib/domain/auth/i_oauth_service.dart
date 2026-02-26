import 'package:flutter_aeroform/domain/models/oauth_token.dart';

/// Abstract interface for OAuth authentication with cloud providers
abstract class IOAuthService {
  /// Initiates OAuth flow by launching browser
  Future<void> authenticate();

  /// Exchanges authorization code for access token
  Future<OAuthToken> exchangeCode(String code);

  /// Refreshes expired access token
  Future<OAuthToken> refreshToken();

  /// Validates token has required scopes
  bool validateScopes(OAuthToken token);

  /// Clears all stored tokens
  Future<void> logout();

  /// Gets current valid access token (refreshes if needed)
  Future<String> getAccessToken();

  /// Returns the provider name (e.g., "linode", "digitalocean")
  String get providerName;

  /// Returns the required scopes for this provider
  List<String> get requiredScopes;
}