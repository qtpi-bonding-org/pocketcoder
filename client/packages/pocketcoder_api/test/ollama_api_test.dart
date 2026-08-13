import 'package:test/test.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart';


/// tests for OllamaApi
void main() {
  final instance = PocketcoderApi().getOllamaApi();

  group(OllamaApi, () {
    //Future<BuiltMap<String, JsonObject>> listOllamaModels() async
    test('test listOllamaModels', () async {
      // TODO
    });

    //Future<BuiltMap<String, JsonObject>> pullOllamaModel(ModelRequest modelRequest) async
    test('test pullOllamaModel', () async {
      // TODO
    });

  });
}
