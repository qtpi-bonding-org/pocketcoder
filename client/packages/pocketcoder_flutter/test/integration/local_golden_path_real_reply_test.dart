// Local (docker-compose, no Linode/VPS) check that goose can actually
// complete a real conversational turn end-to-end -- harness-auth (none
// mode) -> chat -> first prompt -> a genuine assistant reply -- against a
// REAL upstream provider, using the same real client stack
// (local_golden_path_test.dart) but with a real, working API key instead of
// a placeholder.
//
// local_golden_path_test.dart deliberately only proves a genuine credential
// REJECTION with a placeholder key (no billable call needed). This file is
// the complementary "does it actually work" check: it requires a real,
// working key and is skipped entirely without one, so it never runs in a
// bare CI checkout or a normal local dev loop.
//
// The key is read ONLY from an environment variable -- never hardcode a
// real credential into this file.
//
// Run:
//   PB_URL=http://127.0.0.1:8090 \
//   API_TEST_EMAIL=... API_TEST_PASSWORD=... \
//   REAL_PROVIDER_API_KEY=sk-... [REAL_PROVIDER_ID=openrouter] \
//   flutter test test/integration/local_golden_path_real_reply_test.dart
import 'dart:async';
import 'dart:io';

import 'package:ag_ui/ag_ui.dart'
    show
        RunErrorEvent,
        RunFinishedEvent,
        RunStartedEvent,
        TextMessageContentEvent,
        TextMessageRole,
        TextMessageStartEvent;
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
    'goose: harness-auth (none mode) with a real key -> chat -> first prompt '
    'gets a genuine assistant reply',
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
            'without one, since it makes a real, billable upstream call.');
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
          reason: 'provider "$realProviderId" must exist in the catalog -- '
              'set REAL_PROVIDER_ID to a provider this harness actually '
              'supports if the default (openrouter) is not synced here');
      final providerId = providers.first.id;

      final edge = await client.collection('harness_providers').getFullList(
          filter: "harness = '$harnessId' && provider = '$providerId'");
      expect(edge, isNotEmpty,
          reason: 'goose has no harness_providers edge for "$realProviderId" '
              '-- pick a provider goose\'s own catalog actually wires up');

      // (owner, provider) is unique -- replace any leftover key from a
      // previous run, matching how the real onboarding flow overwrites an
      // existing key rather than erroring.
      final existingKeys = await client
          .collection('provider_api_keys')
          .getFullList(filter: "owner = '$userId' && provider = '$providerId'");
      for (final key in existingKeys) {
        await client.collection('provider_api_keys').delete(key.id);
      }
      final savedKey =
          await client.collection('provider_api_keys').create(body: {
        'owner': userId,
        'provider': providerId,
        'api_key': realApiKey,
      });
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

      final chat = await client.collection('chats').create(body: {
        'title': 'golden-path-real-reply-check',
        'user': userId,
        'harness': harnessId,
      });

      final agentApi = generated.AgentApi(dio, generated.standardSerializers);
      final promptRequest = (generated.PromptRequestBuilder()
            ..prompt.add(generated.ContentBlock((b) => b
              ..type = 'text'
              ..text = 'Say hello in exactly three words.')))
          .build();

      // A freshly provisioned/reused harness container can legitimately
      // still be starting -- retry the same handful of times
      // local_golden_path_test.dart tolerates.
      DioException? postError;
      String? runId;
      for (var attempt = 0; attempt < 15; attempt++) {
        try {
          final resp = await agentApi.promptChat(
              chatId: chat.id, promptRequest: promptRequest);
          runId = resp.data?.runId;
          break;
        } on DioException catch (e) {
          if (e.response?.statusCode == 503) {
            await Future<void>.delayed(const Duration(seconds: 2));
            continue;
          }
          postError = e;
          break;
        }
      }
      if (postError != null) {
        fail(
            'promptChat failed outright (HTTP ${postError.response?.statusCode}): '
            '${postError.response?.data}');
      }
      expect(runId, isNotNull,
          reason: 'promptChat never returned 202 after 15 retries');

      final streamClient =
          AgentStreamClient(pocketBase: client, httpClient: http.Client());
      final frames = streamClient.connect(chat.id, cursor: 0);
      RunErrorEvent? runError;
      var finished = false;
      var runStarted = false;
      final assistantText = StringBuffer();
      try {
        await for (final frame in frames.timeout(const Duration(seconds: 60))) {
          final event = frame.event;
          // Ignore the synthetic "sync" seed pair's own RUN_STARTED (a
          // different runId, replayed immediately on connect) so only
          // this run's own assistant text counts.
          if (event is RunStartedEvent && event.runId == runId) {
            runStarted = true;
          }
          if (runStarted &&
              event is TextMessageStartEvent &&
              event.role == TextMessageRole.assistant) {
            // messageId tracking isn't needed here -- this chat is brand
            // new and this test is its only caller, so any assistant text
            // after this run's own RUN_STARTED belongs to this run.
          }
          if (runStarted && event is TextMessageContentEvent) {
            assistantText.write(event.delta);
          }
          if (event is RunFinishedEvent && event.runId == runId) {
            finished = true;
            break;
          }
          if (event is RunErrorEvent) {
            runError = event;
            break;
          }
        }
      } on TimeoutException {
        fail('no RUN_ERROR or RUN_FINISHED event arrived within 60s of '
            'promptChat accepting the run.');
      } finally {
        await streamClient.cancel();
      }

      if (runError != null) {
        fail('expected a genuine assistant reply but got RUN_ERROR '
            '(code "${runError.code}"): ${runError.message}\n'
            'Check that REAL_PROVIDER_API_KEY is a real, currently-valid '
            'key for provider "$realProviderId" and that this harness/'
            'provider pair is one goose\'s own ACP server actually '
            'implements (its own provider registry may use a different '
            'name than the catalog\'s provider_id).');
      }
      expect(finished, isTrue,
          reason: 'expected RUN_FINISHED for this run, got neither '
              'RUN_FINISHED nor RUN_ERROR before the stream loop exited');
      expect(assistantText.toString().trim(), isNotEmpty,
          reason: 'RUN_FINISHED arrived but no assistant-authored text was '
              'ever streamed -- this is exactly the empty-reply gap found '
              'live on 2026-08-28 (a run can finish "successfully" while '
              'silently never invoking the model). A genuine working '
              'credential must produce real reply text, not just a clean '
              'run outcome.');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
