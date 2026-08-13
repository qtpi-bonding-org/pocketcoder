import 'package:test/test.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart';


/// tests for LogsApi
void main() {
  final instance = PocketcoderApi().getLogsApi();

  group(LogsApi, () {
    //Future<BuiltMap<String, JsonObject>> streamContainerLogs(String containerName) async
    test('test streamContainerLogs', () async {
      // TODO
    });

  });
}
