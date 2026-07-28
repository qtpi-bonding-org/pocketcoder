/// Result of a completed OAuth exchange: the access token the target MCP
/// server will use as its bearer/PAT credential, and (if the provider
/// issued one) a refresh token. Ephemeral — never persisted client-side.
typedef McpOAuthTokenPair = ({String accessToken, String? refreshToken});

/// Client-side half of the MCP OAuth flow (see
/// docs/superpowers/specs/2026-07-27-mcp-oauth-flow-design.md, Component
/// 2). Runs the PKCE authorize/browser/claim dance against
/// workers/mcp-oauth-relay and hands back the resulting token pair. This
/// service is a courier, not a holder: callers are responsible for
/// delivering the returned token to this user's own PocketBase (Component
/// 3, via IMcpRepository.deliverOAuthToken) — McpOAuthService never stores
/// it (no flutter_secure_storage use here, unlike LinodeOAuthService's
/// provisioning token, which belongs to the app's own session — this token
/// belongs to the user's gateway).
abstract class IMcpOAuthService {
  /// Runs the full authorize -> browser -> claim flow for [provider] (e.g.
  /// "github") and returns the resulting token pair.
  ///
  /// Throws [McpOAuthException] on any failure, with `isCancelled: true`
  /// when the user dismissed the browser sheet.
  Future<McpOAuthTokenPair> authenticate(String provider);
}
