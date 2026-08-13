import 'package:test/test.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart';


/// tests for AgentApi
void main() {
  final instance = PocketcoderApi().getAgentApi();

  group(AgentApi, () {
    //Future cancelChatSession(String chatId) async
    test('test cancelChatSession', () async {
      // TODO
    });

    //Future<AcceptedResponse> promptChat(String chatId, PromptRequest promptRequest) async
    test('test promptChat', () async {
      // TODO
    });

    //Future<BuiltMap<String, JsonObject>> respondToElicitation(String chatId, String id, BuiltMap<String, JsonObject> requestBody) async
    test('test respondToElicitation', () async {
      // TODO
    });

    //Future<BuiltMap<String, JsonObject>> respondToPermission(String chatId, String id, BuiltMap<String, JsonObject> requestBody) async
    test('test respondToPermission', () async {
      // TODO
    });

    //Future<BuiltMap<String, JsonObject>> setChatConfigOption(String chatId, ConfigOptionRequest configOptionRequest) async
    test('test setChatConfigOption', () async {
      // TODO
    });

    //Future<BuiltMap<String, JsonObject>> setChatMode(String chatId, ModeRequest modeRequest) async
    test('test setChatMode', () async {
      // TODO
    });

    //Future<BuiltMap<String, JsonObject>> streamChatEvents(String chatId, { int cursor }) async
    test('test streamChatEvents', () async {
      // TODO
    });

  });
}
