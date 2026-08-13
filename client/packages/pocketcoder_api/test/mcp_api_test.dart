import 'package:test/test.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart';


/// tests for McpApi
void main() {
  final instance = PocketcoderApi().getMcpApi();

  group(McpApi, () {
    //Future<BuiltMap<String, JsonObject>> executeMcpRequest(BuiltMap<String, JsonObject> requestBody) async
    test('test executeMcpRequest', () async {
      // TODO
    });

    //Future<BuiltMap<String, JsonObject>> storeMcpOAuthToken(BuiltMap<String, JsonObject> requestBody) async
    test('test storeMcpOAuthToken', () async {
      // TODO
    });

  });
}
