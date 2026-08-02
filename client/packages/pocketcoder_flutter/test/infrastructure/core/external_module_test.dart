import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/infrastructure/core/external_module.dart';

// `_$ExternalModule` lives in the generated `bootstrap.config.dart` and is the
// runtime DI implementation; it's not visible to tests in this package, so we
// inline a trivial concrete subclass here purely to reach the
// `mcpOAuthRelayBaseUrl` getter exposed by the abstract class.
class _ConcreteExternalModule extends ExternalModule {}

void main() {
  test('mcpOAuthRelayBaseUrl points at the real deployed Worker', () {
    final module = _ConcreteExternalModule();
    expect(
      module.mcpOAuthRelayBaseUrl,
      'https://pocketcoder-mcp-oauth-relay.gp-c53.workers.dev',
    );
  });
}
