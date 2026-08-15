import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/core/auth_aware_http_client.dart';

class _QueueClient extends http.BaseClient {
  _QueueClient(this._responses);

  final List<http.StreamedResponse> _responses;
  final List<http.BaseRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    return _responses.removeAt(0);
  }
}

http.StreamedResponse _response(int statusCode, String body) {
  return http.StreamedResponse(
    Stream<List<int>>.value(body.codeUnits),
    statusCode,
  );
}

void main() {
  test('refreshes and replays deployment SSE GETs', () async {
    final state = AuthHttpState();
    var token = 'old-token';
    var refreshes = 0;
    state.configureDeployment(
      'https://deployment.example',
      tokenProvider: () => token,
    );
    state.refresh = () async {
      refreshes++;
      token = 'new-token';
      return AuthRefreshResult.refreshed;
    };
    final inner = _QueueClient([
      _response(401, 'expired'),
      _response(200, 'event-stream'),
    ]);
    final client = AuthAwareHttpClient(state, inner: inner);

    final response = await client.send(
      http.Request('GET', Uri.parse('https://deployment.example/stream'))
        ..headers['Authorization'] = 'old-token',
    );

    expect(response.statusCode, 200);
    expect(refreshes, 1);
    expect(inner.requests, hasLength(2));
    expect(inner.requests.last.headers['Authorization'], 'new-token');
  });

  test('refreshes but does not replay deployment mutations', () async {
    final state = AuthHttpState();
    state.configureDeployment(
      'https://deployment.example',
      tokenProvider: () => 'token',
    );
    var refreshes = 0;
    state.refresh = () async {
      refreshes++;
      return AuthRefreshResult.refreshed;
    };
    final inner = _QueueClient([_response(401, 'expired')]);
    final client = AuthAwareHttpClient(state, inner: inner);

    final response = await client.send(
      http.Request('POST', Uri.parse('https://deployment.example/mutate')),
    );

    expect(response.statusCode, 401);
    expect(refreshes, 1);
    expect(inner.requests, hasLength(1));
  });

  test('does not refresh unrelated relay requests', () async {
    final state = AuthHttpState();
    state.configureDeployment(
      'https://deployment.example',
      tokenProvider: () => 'token',
    );
    var refreshes = 0;
    state.refresh = () async {
      refreshes++;
      return AuthRefreshResult.refreshed;
    };
    final inner = _QueueClient([_response(401, 'unauthorized')]);
    final client = AuthAwareHttpClient(state, inner: inner);

    final response = await client.send(
      http.Request('GET', Uri.parse('https://relay.example/metadata')),
    );

    expect(response.statusCode, 401);
    expect(refreshes, 0);
  });
}
