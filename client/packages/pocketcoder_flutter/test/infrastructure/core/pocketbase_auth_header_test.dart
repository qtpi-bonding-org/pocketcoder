import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/infrastructure/agent/agent_stream_client.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketbase_auth_header.dart';

class _Client extends http.BaseClient {
  http.BaseRequest? request;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest value) async {
    request = value;
    return http.StreamedResponse(const Stream<List<int>>.empty(), 200,
        request: value);
  }
}

PocketBase _pb([String? token]) {
  final pb = PocketBase('http://pb.test');
  if (token != null) pb.authStore.save(token, null);
  return pb;
}

void main() {
  test('returns the raw token without a Bearer prefix', () {
    expect(pocketBaseAuthHeaderValue(_pb('token-123')), 'token-123');
  });

  test('returns null when signed out', () {
    expect(pocketBaseAuthHeaderValue(_pb()), isNull);
  });

  test('agent stream fails before sending when signed out', () async {
    final client = _Client();
    final stream = AgentStreamClient(pocketBase: _pb(), httpClient: client)
        .connect('chat', cursor: 0);

    await expectLater(stream, emitsError(isA<StateError>()));
    expect(client.request, isNull);
  });
}
