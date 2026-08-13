import 'package:test/test.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart';


/// tests for PushApi
void main() {
  final instance = PocketcoderApi().getPushApi();

  group(PushApi, () {
    //Future<BuiltMap<String, JsonObject>> sendPushNotification(BuiltMap<String, JsonObject> requestBody) async
    test('test sendPushNotification', () async {
      // TODO
    });

  });
}
