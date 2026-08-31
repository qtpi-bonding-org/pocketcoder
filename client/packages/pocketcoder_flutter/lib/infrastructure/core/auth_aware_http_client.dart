import 'package:http/http.dart' as http;
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';

/// Shared transport state for requests made against the user's deployment.
class AuthHttpState {
  Uri? deploymentOrigin;
  String Function()? tokenProvider;
  Future<AuthRefreshResult> Function()? refresh;

  void configureDeployment(
    String baseUrl, {
    required String Function() tokenProvider,
  }) {
    updateDeploymentOrigin(baseUrl);
    this.tokenProvider = tokenProvider;
  }

  /// Retargets which origin's 401s are eligible for auth-refresh recovery,
  /// leaving [tokenProvider]/[refresh] untouched. Needed whenever the
  /// active deployment's base URL changes after DI-time configuration --
  /// e.g. a real login to the user's own deployment, distinct from the
  /// local-default origin [configureDeployment] was first called with.
  void updateDeploymentOrigin(String baseUrl) {
    final parsed = Uri.parse(baseUrl);
    deploymentOrigin = Uri(
      scheme: parsed.scheme,
      host: parsed.host,
      port: parsed.hasPort ? parsed.port : null,
    );
  }
}

/// HTTP client that performs shared PocketBase session recovery.
///
/// It is used by SSE, PocketBase CRUD, and other `package:http` callers. It
/// never replays a mutation automatically; only GET/HEAD requests are safe to
/// reconstruct after a 401.
class AuthAwareHttpClient extends http.BaseClient {
  static const skipRefreshHeader = 'X-PocketCoder-Skip-Auth-Refresh';

  AuthAwareHttpClient(this.state, {http.Client? inner})
      : _inner = inner ?? http.Client();

  final AuthHttpState state;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (!_shouldRecover(request, response)) {
      return response;
    }

    // Buffer the original response so unsafe requests can still return it
    // after the refresh attempt without losing its body stream.
    final body = await response.stream.toBytes();
    final original = _restoreResponse(response, body);
    final refresh = state.refresh;
    if (refresh == null) return original;

    final result = await refresh();
    if (result != AuthRefreshResult.refreshed || !_canReplay(request)) {
      return original;
    }

    final retry = http.Request(request.method, request.url)
      ..headers.addAll(request.headers);
    final token = state.tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      retry.headers['Authorization'] = token;
    }
    return _inner.send(retry);
  }

  bool _shouldRecover(
    http.BaseRequest request,
    http.StreamedResponse response,
  ) {
    if (response.statusCode != 401 ||
        request.headers[skipRefreshHeader] == '1' ||
        state.refresh == null) {
      return false;
    }
    final origin = state.deploymentOrigin;
    return origin != null && _sameOrigin(origin, request.url);
  }

  static bool _canReplay(http.BaseRequest request) {
    final method = request.method.toUpperCase();
    return method == 'GET' || method == 'HEAD';
  }

  static bool _sameOrigin(Uri expected, Uri actual) {
    return expected.scheme == actual.scheme &&
        expected.host == actual.host &&
        expected.port == actual.port;
  }

  static http.StreamedResponse _restoreResponse(
    http.StreamedResponse response,
    List<int> body,
  ) {
    return http.StreamedResponse(
      Stream<List<int>>.value(body),
      response.statusCode,
      contentLength: body.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() {
    _inner.close();
  }
}
