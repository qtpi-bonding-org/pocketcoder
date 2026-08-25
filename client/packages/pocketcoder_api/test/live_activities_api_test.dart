import 'package:test/test.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart';


/// tests for LiveActivitiesApi
void main() {
  final instance = PocketcoderApi().getLiveActivitiesApi();

  group(LiveActivitiesApi, () {
    //Future<BuiltMap<String, JsonObject>> endLiveActivity(String id) async
    test('test endLiveActivity', () async {
      // TODO
    });

  });
}
