import 'package:test/test.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart';


/// tests for SchedulesApi
void main() {
  final instance = PocketcoderApi().getSchedulesApi();

  group(SchedulesApi, () {
    //Future<BuiltMap<String, JsonObject>> runScheduleNow(BuiltMap<String, JsonObject> requestBody) async
    test('test runScheduleNow', () async {
      // TODO
    });

  });
}
