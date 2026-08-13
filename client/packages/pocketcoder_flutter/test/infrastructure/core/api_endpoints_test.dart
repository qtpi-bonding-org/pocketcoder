import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/infrastructure/core/api_endpoints.dart';

void main() {
  test('only incremental and opaque transports retain handwritten paths', () {
    expect(
      StreamingEndpoints.agentStream('chat-1'),
      '/api/pocketcoder/v1/chats/chat-1/stream',
    );
    expect(StreamingEndpoints.ollamaPull, '/api/pocketcoder/v1/ollama/pull');
    expect(
      StreamingEndpoints.logs('pocketcoder'),
      '/api/pocketcoder/v1/logs/pocketcoder',
    );
    expect(
      StreamingEndpoints.observability,
      '/api/pocketcoder/v1/proxy/observability/',
    );
  });
}
