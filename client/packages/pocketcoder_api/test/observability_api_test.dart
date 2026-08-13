import 'package:test/test.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart';


/// tests for ObservabilityApi
void main() {
  final instance = PocketcoderApi().getObservabilityApi();

  group(ObservabilityApi, () {
    //Future proxyObservability(String path) async
    test('test proxyObservability', () async {
      // TODO
    });

  });
}
