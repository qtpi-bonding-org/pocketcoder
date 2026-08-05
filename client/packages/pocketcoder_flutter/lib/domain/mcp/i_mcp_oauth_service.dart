/// Result of a completed OAuth exchange: the access token the target MCP
/// server will use as its bearer/PAT credential, and (if the provider
/// issued one) a refresh token. Ephemeral — never persisted client-side.
typedef McpOAuthTokenPair = ({String accessToken, String? refreshToken});

/// A provider workers/oauth-relay currently has configured (both a
/// PROVIDERS entry and live wrangler secrets) — see
/// docs/superpowers/specs/2026-07-27-mcp-oauth-provider-discovery-design.md.
/// `displayName` is human-facing ("GitHub"); `id` is the opaque string
/// stored in McpServer.oauthProvider and passed to authenticate().
typedef McpOAuthProvider = ({String id, String displayName});

/// Client-side half of the MCP OAuth flow (see
/// docs/superpowers/specs/2026-07-27-mcp-oauth-flow-design.md, Component
/// 2, as refined by the provider-discovery addendum). Runs the PKCE
/// authorize/browser/claim dance against workers/oauth-relay and hands
/// back the resulting token pair. This service is a courier, not a
/// holder: callers are responsible for delivering the returned token to
/// this user's own PocketBase (Component 3, via
/// IMcpRepository.deliverOAuthToken) — McpOAuthService never stores it (no
/// flutter_secure_storage use here, unlike LinodeOAuthService's
/// provisioning token, which belongs to the app's own session — this
/// token belongs to the user's gateway).
///
/// Deliberately holds **no** per-provider knowledge (no authorize URLs,
/// no scopes, no client_ids) — the Worker holds all of that server-side
/// and builds the authorize URL itself at GET /authorize time. Adding a
/// new OAuth provider is therefore a Worker-only change (one PROVIDERS
/// entry + one `wrangler secret put`), never a Flutter code change or app
/// release. See the provider-discovery spec's Problem section.
abstract class IMcpOAuthService {
  /// Returns the list of providers the Worker currently has configured
  /// (PROVIDERS entry + live secrets). Cached in-memory for the app
  /// session after the first successful fetch — a transient network
  /// failure must not poison the app session with an empty list.
  ///
  /// Callers (McpCubit) use this to gate the CONNECT button: a server
  /// whose oauthProvider isn't in this list should show a "not yet
  /// configured" state instead of launching a browser sheet that would
  /// fail after the fact.
  Future<List<McpOAuthProvider>> supportedProviders();

  /// Runs the full authorize -> browser -> claim flow for [provider] (e.g.
  /// "github") and returns the resulting token pair.
  ///
  /// Throws [McpOAuthException] on any failure, with `isCancelled: true`
  /// when the user dismissed the browser sheet.
  Future<McpOAuthTokenPair> authenticate(String provider);
}
