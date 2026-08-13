import 'package:test/test.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart';


/// tests for HarnessAuthApi
void main() {
  final instance = PocketcoderApi().getHarnessAuthApi();

  group(HarnessAuthApi, () {
    //Future<BuiltMap<String, JsonObject>> cancelHarnessAuth(BuiltMap<String, JsonObject> requestBody) async
    test('test cancelHarnessAuth', () async {
      // TODO
    });

    //Future<BuiltMap<String, JsonObject>> disconnectHarnessAuth(BuiltMap<String, JsonObject> requestBody) async
    test('test disconnectHarnessAuth', () async {
      // TODO
    });

    //Future<BuiltMap<String, JsonObject>> getHarnessAuthStatus(BuiltMap<String, JsonObject> requestBody) async
    test('test getHarnessAuthStatus', () async {
      // TODO
    });

    //Future<BuiltMap<String, JsonObject>> pollHarnessAuth(BuiltMap<String, JsonObject> requestBody) async
    test('test pollHarnessAuth', () async {
      // TODO
    });

    //Future<BuiltMap<String, JsonObject>> startHarnessAuth(BuiltMap<String, JsonObject> requestBody) async
    test('test startHarnessAuth', () async {
      // TODO
    });

    //Future<BuiltMap<String, JsonObject>> submitHarnessAuth(BuiltMap<String, JsonObject> requestBody) async
    test('test submitHarnessAuth', () async {
      // TODO
    });

  });
}
