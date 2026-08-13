import 'package:test/test.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart';


/// tests for ReleaseApi
void main() {
  final instance = PocketcoderApi().getReleaseApi();

  group(ReleaseApi, () {
    //Future<BuiltMap<String, JsonObject>> getReleaseCompatibility() async
    test('test getReleaseCompatibility', () async {
      // TODO
    });

    //Future<BuiltMap<String, JsonObject>> getReleaseStatus() async
    test('test getReleaseStatus', () async {
      // TODO
    });

  });
}
