// Requires a real provider key (REAL_PROVIDER_API_KEY) -- a placeholder
// key proves credential rejection, never live-config correction.
import 'dart:async';
import 'dart:io';

import 'package:ag_ui/ag_ui.dart'
    show RunErrorEvent, RunFinishedEvent, StateDeltaEvent;
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart' as pocketbase;
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart' as generated;
import 'package:pocketcoder_flutter/infrastructure/agent/agent_stream_client.dart';

void main() {
  final baseUrl = Platform.environment['PB_URL'] ?? 'http://127.0.0.1:8090';
  final email = Platform.environment['API_TEST_EMAIL'];
  final password = Platform.environment['API_TEST_PASSWORD'];
  final realApiKey = Platform.environment['REAL_PROVIDER_API_KEY'];
  final realProviderId =
      Platform.environment['REAL_PROVIDER_ID'] ?? 'openrouter';

  test(
    'goose: swapping the live model TWICE in one chat reaches the client '
    'both times, not just the first',
    () async {
      if (email == null || password == null) {
        markTestSkipped('API_TEST_EMAIL/API_TEST_PASSWORD not set -- run via '
            'tests/compose/api/run.sh, not directly');
        return;
      }
      if (realApiKey == null || realApiKey.isEmpty) {
        markTestSkipped(
            'REAL_PROVIDER_API_KEY not set -- this test requires a real, '
            'working (ideally low-limit/scoped) API key and is skipped '
            'without one, since a placeholder key never establishes a '
            'live-config session to swap models on.');
        return;
      }

      final client = pocketbase.PocketBase(baseUrl);
      await client.collection('users').authWithPassword(email, password);
      final userId = client.authStore.record!.id;
      final token = client.authStore.token;

      final harnesses = await client
          .collection('harnesses')
          .getFullList(filter: "cli_id = 'goose'");
      expect(harnesses, isNotEmpty, reason: 'goose harness must be seeded');
      final harnessId = harnesses.first.id;

      final providers = await client
          .collection('providers')
          .getFullList(filter: "provider_id = '$realProviderId'");
      expect(providers, isNotEmpty,
          reason: 'provider "$realProviderId" must exist in the catalog');
      final providerId = providers.first.id;

      final existingKeys = await client
          .collection('provider_api_keys')
          .getFullList(filter: "owner = '$userId' && provider = '$providerId'");
      for (final key in existingKeys) {
        await client.collection('provider_api_keys').delete(key.id);
      }
      // Triggers modelcatalog.RegisterCredentialHooks synchronously, so the
      // harness_models rows queried below exist immediately.
      pocketbase.RecordModel savedKey;
      try {
        savedKey = await client.collection('provider_api_keys').create(body: {
          'owner': userId,
          'provider': providerId,
          'api_key': realApiKey,
        });
      } on pocketbase.ClientException catch (e) {
        fail('provider_api_keys.create failed: ${e.statusCode} ${e.response}');
      }
      addTearDown(
          () => client.collection('provider_api_keys').delete(savedKey.id));

      final dio =
          Dio(BaseOptions(baseUrl: baseUrl, headers: {'Authorization': token}));
      final harnessAuthApi =
          generated.HarnessAuthApi(dio, generated.standardSerializers);
      final startResp = await harnessAuthApi.startHarnessAuth(
        harnessRequest: (generated.HarnessRequestBuilder()
              ..harness = harnessId
              ..provider = providerId
              ..mode = generated.HarnessRequestModeEnum.none
              ..visibility = 'personal')
            .build(),
      );
      expect(startResp.statusCode, 200,
          reason: 'harness-auth/start: ${startResp.data}');

      final harnessModels = await client.collection('harness_models').getFullList(
          filter: "harness = '$harnessId'");
      final modelIds = <String>{};
      for (final hm in harnessModels) {
        final modelRecId = hm.data['model'] as String?;
        if (modelRecId == null) continue;
        try {
          final model = await client.collection('models').getOne(modelRecId);
          if (model.data['provider'] == providerId) {
            modelIds.add(hm.data['harness_model_id'] as String);
          }
        } catch (_) {
          continue;
        }
        if (modelIds.length >= 2) break;
      }
      expect(modelIds.length, greaterThanOrEqualTo(2),
          reason: 'need at least 2 synced $realProviderId models for goose '
              'to swap between -- got: $modelIds');
      final modelA = modelIds.elementAt(0);
      final modelB = modelIds.elementAt(1);

      pocketbase.RecordModel chat;
      try {
        chat = await client.collection('chats').create(body: {
          'title': 'model-swap-check',
          'user': userId,
          'harness': harnessId,
        });
      } on pocketbase.ClientException catch (e) {
        fail('chats.create failed: ${e.statusCode} ${e.response}');
      }

      final agentApi = generated.AgentApi(dio, generated.standardSerializers);
      final streamClient =
          AgentStreamClient(pocketBase: client, httpClient: http.Client());
      final frames = streamClient.connect(chat.id, cursor: 0);
      final sub = StreamIterator(frames);
      addTearDown(() async {
        await sub.cancel();
        await streamClient.cancel();
      });

      Future<StreamFrame> nextFrame(Duration timeout) async {
        final hasNext = await sub.moveNext().timeout(timeout);
        if (!hasNext) {
          throw StateError('event stream closed unexpectedly');
        }
        return sub.current;
      }

      Future<void> sendPrompt(String text) async {
        DioException? postError;
        for (var attempt = 0; attempt < 15; attempt++) {
          try {
            await agentApi.promptChat(
                chatId: chat.id,
                promptRequest: (generated.PromptRequestBuilder()
                      ..prompt.add(generated.ContentBlock((b) => b
                        ..type = 'text'
                        ..text = text)))
                    .build());
            return;
          } on DioException catch (e) {
            if (e.response?.statusCode == 503) {
              await Future<void>.delayed(const Duration(seconds: 2));
              continue;
            }
            postError = e;
            break;
          }
        }
        fail('promptChat failed: ${postError?.response?.data}');
      }

      Future<void> waitForRunFinished() async {
        while (true) {
          final frame = await nextFrame(const Duration(seconds: 60));
          final event = frame.event;
          if (event is RunErrorEvent) {
            fail('expected the first prompt to establish a session but got '
                'RUN_ERROR (code "${event.code}"): ${event.message}');
          }
          if (event is RunFinishedEvent) return;
        }
      }

      Future<String?> currentModelInConfig(String? previous) async {
        final deadline = DateTime.now().add(const Duration(seconds: 30));
        while (DateTime.now().isBefore(deadline)) {
          final remaining = deadline.difference(DateTime.now());
          if (remaining.isNegative) break;
          final frame = await nextFrame(remaining);
          final event = frame.event;
          if (event is! StateDeltaEvent) continue;
          for (final op in event.delta) {
            if (op['path'] != '/pocketcoder/config') continue;
            final options = (op['value'] as Map?)?['options'] as List?;
            if (options == null) continue;
            for (final o in options) {
              final m = Map<String, dynamic>.from(o as Map);
              if (m['id'] == 'model') {
                final current = m['currentValue']?.toString();
                if (current != null && current != previous) return current;
              }
            }
          }
        }
        return null;
      }

      await sendPrompt('hi');
      await waitForRunFinished();

      final setConfig = generated.AgentApi(dio, generated.standardSerializers);
      try {
        await setConfig.setChatConfigOption(
          chatId: chat.id,
          configOptionRequest: (generated.ConfigOptionRequestBuilder()
                ..configId = 'model'
                ..value = modelA)
              .build(),
        );
      } on DioException catch (e) {
        fail('setChatConfigOption(modelA) failed: ${e.response?.statusCode} '
            '${e.response?.data}');
      }
      final afterFirstSwap = await currentModelInConfig(null);
      expect(afterFirstSwap, modelA,
          reason: 'the FIRST model swap (to $modelA) never reached the '
              'client as a config STATE_DELTA -- got: $afterFirstSwap');

      await setConfig.setChatConfigOption(
        chatId: chat.id,
        configOptionRequest: (generated.ConfigOptionRequestBuilder()
              ..configId = 'model'
              ..value = modelB)
            .build(),
      );
      final afterSecondSwap = await currentModelInConfig(afterFirstSwap);
      expect(afterSecondSwap, modelB,
          reason: 'the SECOND model swap (to $modelB) never reached the '
              'client as a config STATE_DELTA -- got: $afterSecondSwap '
              '(stuck on the first swap\'s value if equal to $modelA)');

      final updatedChat = await client.collection('chats').getOne(chat.id);
      final hmOverride = updatedChat.data['harness_model_override'] as String?;
      expect(hmOverride, isNotNull,
          reason: 'chats.harness_model_override was never set after either '
              'swap');
      final hmRecord =
          await client.collection('harness_models').getOne(hmOverride!);
      expect(hmRecord.data['harness_model_id'], modelB,
          reason: 'chats.harness_model_override still points at the FIRST '
              'swap\'s model ($modelA) instead of the second ($modelB) -- '
              'the persisted override was never updated on the second swap');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
