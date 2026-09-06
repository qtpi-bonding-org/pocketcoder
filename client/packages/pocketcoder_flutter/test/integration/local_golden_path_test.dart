// Local (docker-compose, no Linode/VPS) golden-path check: harness auth ->
// chat creation -> first prompt, driven through the REAL generated
// pocketcoder_api client (the exact request/response encoding the app uses)
// against a REAL PocketBase server -- not a mock, not a direct Go function
// call. This is deliberately a different layer than
// server/pocketbase/internal/sessionprofile's Go unit tests (which cover
// the same logic in-process, bypassing HTTP/JSON entirely) and different
// from tests/compose/api/core.bats (curl+jq, no client-side type contract).
//
// Every bug fixed 2026-08-28 was fully reproducible at this layer without
// a real LLM API key or a real OAuth login:
//   - BaseDao's local-first chat-creation race (client-only, not exercised
//     here -- this test creates the chat directly via the real PocketBase
//     SDK, synchronously, the way this test's own assertions need it to
//     exist before it's used).
//   - sessionprofile.Build never resolving a provider without an explicit
//     harness_model_override.
//   - renderEnv silently never injecting an API key when
//     credential_selections.mode == "none".
//   - live-config harnesses (Goose, OpenCode) never getting Provider/Model
//     resolved for the coordinator's live ACP correction.
// All four surface as either "Authentication required" (ACP code -32000)
// or an empty-provider failure at the exact call this test makes.
//
// The `promptChat` POST only queues a run -- for goose/opencode
// (AccountLogin == false, api_key/"none" mode) it returns 202 Accepted the
// moment the prompt is accepted, well before the harness container makes
// its own call to the upstream provider. A genuine "the placeholder key was
// rejected" outcome therefore never appears on that POST response; it
// arrives later as a RUN_ERROR event on the chat's SSE stream
// (`/chats/{id}/stream`), coded `provider_api_key_invalid` (see
// coordinator/provider_auth.go's providerApiKeyFailure, added 2026-08-28
// specifically so api_key-mode harnesses stop collapsing a real credential
// rejection into the same generic "goose_unavailable" code as a crashed
// container or a missing Docker network). This test listens on that stream
// for exactly that code -- not "any error that isn't the known bug" -- so it
// cannot be fooled by an unrelated infra-completeness failure (missing
// `pocketcoder-harness-egress` network, `pocketcoder-harness-*` image pull
// denied, etc.), all of which are real gaps in a bare local dev checkout
// and none of which prove the credential was ever used.
//
// Run via tests/compose/api/run.sh (brings up the real docker-compose
// stack first) -- this file alone assumes PocketBase is already reachable
// at $PB_URL (default http://127.0.0.1:8090, PocketBase's host-published
// port from docker-compose.yml) and that $API_TEST_EMAIL/$API_TEST_PASSWORD
// are seeded there.
import 'dart:async';
import 'dart:io';

import 'package:ag_ui/ag_ui.dart' show RunErrorEvent, RunFinishedEvent;
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

  /// Runs the full harness-auth -> chat -> first-prompt path for one
  /// multi-provider (api-key/"none" mode) harness, and asserts we get PAST
  /// the resolution bugs fixed 2026-08-28 all the way to a genuine upstream
  /// credential rejection -- not that we get a real LLM response, which
  /// would need a real, billable provider credential. A placeholder API key
  /// still exercises every one of this session's fixes: if the
  /// sessionprofile/renderEnv resolution regresses, this fails immediately
  /// with the ACP "Authentication required" symptom logged live; if the
  /// local environment's harness images/networks are incomplete, this fails
  /// with an explicit, distinct diagnostic instead of a false pass.
  Future<void> checkApiKeyHarnessGoldenPath(String cliId) async {
    final client = pocketbase.PocketBase(baseUrl);
    await client.collection('users').authWithPassword(email!, password!);
    final userId = client.authStore.record!.id;
    final token = client.authStore.token;

    final harnesses = await client
        .collection('harnesses')
        .getFullList(filter: "cli_id = '$cliId'");
    expect(harnesses, isNotEmpty, reason: '$cliId harness must be seeded');
    final harnessId = harnesses.first.id;

    final edges = await client
        .collection('harness_providers')
        .getFullList(filter: "harness = '$harnessId'", expand: 'provider');
    expect(edges, isNotEmpty,
        reason: '$cliId must have at least one harness_providers edge -- run '
            'the modelcatalog sync, or this test cannot pick a provider');
    // modelcatalog syncs in hundreds of catalog providers (real backends
    // like openai/anthropic alongside routers, regional resellers, and
    // synthetic test fixtures like "agnes") with no guaranteed ordering --
    // picking edges.first is at the mercy of whatever the sync happened to
    // insert first. A live-config harness's coordinator.PerSessionApplier
    // sends the provider's slug straight to the harness's own ACP session
    // config, which only recognizes a fixed set of real backends; anything
    // else fails with "Failed to get provider: Provider not set" -- a
    // fixture-selection problem, not a credential-resolution regression.
    // Prefer a known-real backend deterministically instead.
    const knownProviderSlugs = ['openai', 'anthropic', 'google'];
    final knownEdge = edges.where((edge) {
      final slug = edge.get<String?>('expand.provider.provider_id');
      return knownProviderSlugs.contains(slug);
    }).firstOrNull;
    expect(knownEdge, isNotNull,
        reason: '$cliId has no harness_providers edge for any of '
            '$knownProviderSlugs -- the harness only exposes catalog '
            'providers its own ACP server does not implement, so this test '
            'cannot reach a real upstream credential check');
    final providerId = knownEdge!.data['provider'] as String;

    // (owner, provider) is unique -- replace any leftover key from a
    // previous run of this test against the same long-lived docker-compose
    // stack, matching how the real onboarding flow overwrites an existing
    // key rather than erroring.
    final existingKeys = await client
        .collection('provider_api_keys')
        .getFullList(filter: "owner = '$userId' && provider = '$providerId'");
    for (final key in existingKeys) {
      await client.collection('provider_api_keys').delete(key.id);
    }
    await client.collection('provider_api_keys').create(body: {
      'owner': userId,
      'provider': providerId,
      'api_key':
          'sk-golden-path-check-placeholder-${DateTime.now().millisecondsSinceEpoch}',
    });

    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: {'Authorization': token},
    ));
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
    expect(startResp.data?.mode, generated.HarnessAuthStatusModeEnum.none);

    final chat = await client.collection('chats').create(body: {
      'title': 'golden-path-check-$cliId',
      'user': userId,
      'harness': harnessId,
    });

    final agentApi = generated.AgentApi(dio, generated.standardSerializers);
    final promptRequest = (generated.PromptRequestBuilder()
          ..prompt.add(generated.ContentBlock((b) => b
            ..type = 'text'
            ..text = 'hello')))
        .build();

    // A freshly provisioned harness container can legitimately still be
    // starting (a real, transient 503) -- retry the same handful of times
    // the real app's own error surface tolerates, per the live log this
    // session captured ("Harness is starting; retry shortly"). The
    // generated client throws DioException on any non-2xx response (it does
    // NOT attempt to deserialize the success type first) -- inspect
    // e.response the same way AgentActionsApi._call does in the real app.
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
      final body = postError.response?.data;
      final message = body is Map ? body['message']?.toString() ?? '' : '';
      final statusCode = postError.response?.statusCode;
      // "Authentication required" here means sessionprofile/renderEnv never
      // resolved or injected a credential at all -- the exact regression
      // this whole test exists to catch.
      expect(message, isNot(contains('Authentication required')),
          reason: 'regression of the 2026-08-28 sessionprofile/renderEnv '
              'fixes: the credential was never resolved/injected at all. '
              'Full response: $body');
      // 502 "Harness failed to start" (agent.go's ErrHarnessFailed) covers
      // every underlying provisioning failure -- missing Docker network,
      // image pull denied, etc. -- none of which reach the harness process
      // at all, let alone the upstream provider. Treating this as a pass
      // was the exact bug this test tightening fixes: it silently passed on
      // three different infra-completeness failures discovered live on
      // 2026-08-28 (missing mcp-gateway/harness-egress network, missing
      // pocketcoder-harness-opencode image) that prove nothing about
      // credential resolution.
      fail('harness never started (HTTP $statusCode): $body\n'
          'This environment is missing something promptChat needs before '
          'it can even reach the harness container (a Docker network, a '
          'pre-built harness image, etc.) -- it is an environment gap, not '
          'evidence either way about the credential-resolution fixes. Run '
          'tests/compose/api/run.sh (which builds/starts the full stack) '
          'rather than this file directly, and check the pocketbase '
          'container logs for the actual provisioning failure.');
    }
    expect(runId, isNotNull,
        reason: 'promptChat never returned 202 after 15 retries');

    // The credential-resolution fixes only prove themselves once the
    // harness container actually calls the upstream provider with the
    // placeholder key -- that happens asynchronously, after promptChat's
    // 202, and its outcome streams over SSE as a RUN_ERROR event.
    //
    // The stream also carries a synthetic "sync" seed pair -- a
    // RUN_STARTED/RUN_FINISHED emitted immediately on connect with a runId
    // that does NOT match this test's actual run (bridge.SeedSession's
    // initial replay/snapshot, unrelated to any real prompt). A check that
    // takes the first RunFinishedEvent regardless of runId is fooled by
    // this every time -- confirmed live 2026-08-28: goose "finished
    // successfully" against a placeholder key purely because of this
    // artifact, while the actual run underneath had failed with
    // "dial harness: harness target is required". Only trust a
    // RunFinishedEvent whose runId matches this test's own run. RUN_ERROR
    // carries no runId on the wire (see ag-ui's RunErrorEvent), but that's
    // fine here: this chat was just created and this test is its only
    // caller, so any RUN_ERROR on it is necessarily this run's -- the
    // synthetic seed pair itself never includes a RUN_ERROR.
    final streamClient = AgentStreamClient(
      pocketBase: client,
      httpClient: http.Client(),
    );
    final frames = streamClient.connect(chat.id, cursor: 0);
    RunErrorEvent? runError;
    var finished = false;
    try {
      await for (final frame in frames.timeout(const Duration(seconds: 60))) {
        final event = frame.event;
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
      fail('no RUN_ERROR or RUN_FINISHED event arrived on the chat stream '
          'within 60s of promptChat accepting the run -- either the '
          'harness container never actually attempted the upstream call, '
          'or its event never reached the hub. Check the pocketbase and '
          'harness container logs.');
    } finally {
      await streamClient.cancel();
    }

    if (finished) {
      fail('run finished successfully with a placeholder API key -- this '
          'should be impossible unless the harness is silently pointed at '
          'a real, working credential or a free/local model, either of '
          'which would defeat this test\'s purpose.');
    }

    expect(runError, isNotNull,
        reason: 'expected a RUN_ERROR event, got neither RUN_ERROR nor '
            'RUN_FINISHED before the stream loop exited');
    // This is the actual "right" passing condition: the harness reached the
    // upstream provider and got a genuine credential rejection back
    // (coordinator.providerApiKeyFailure's code, added 2026-08-28
    // specifically so api_key harnesses stop collapsing a real auth
    // rejection into the same generic "goose_unavailable" code as a crashed
    // container). Anything else -- including the previous, too-loose
    // "goose_unavailable" catch-all -- means either a real regression or an
    // incomplete environment, and must fail loudly rather than pass.
    expect(runError!.code, 'provider_api_key_invalid',
        reason: 'expected a genuine upstream credential rejection '
            '(provider_api_key_invalid), got RUN_ERROR code '
            '"${runError.code}" with message "${runError.message}". A '
            '"goose_unavailable" code here most likely means the harness '
            'container crashed or could not reach the upstream provider at '
            'all (network egress, DNS, etc.) rather than a real '
            'credential check -- that is a distinct failure from what this '
            'test exists to verify.');
  }

  group('local golden path (docker-compose, no VPS)', () {
    test(
      'goose: harness-auth (none mode) -> chat -> first prompt gets a real '
      'upstream credential rejection instead of Authentication required or '
      'a generic goose_unavailable',
      () async {
        if (email == null || password == null) {
          markTestSkipped('API_TEST_EMAIL/API_TEST_PASSWORD not set -- run via '
              'tests/compose/api/run.sh, not directly');
          return;
        }
        await checkApiKeyHarnessGoldenPath('goose');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'opencode: harness-auth (none mode) -> chat -> first prompt gets a '
      'real upstream credential rejection instead of Authentication '
      'required or a generic goose_unavailable',
      () async {
        if (email == null || password == null) {
          markTestSkipped('API_TEST_EMAIL/API_TEST_PASSWORD not set -- run via '
              'tests/compose/api/run.sh, not directly');
          return;
        }
        await checkApiKeyHarnessGoldenPath('opencode');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
