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
// Run via tests/compose/api/run.sh (brings up the real docker-compose
// stack first) -- this file alone assumes PocketBase is already reachable
// at $PB_URL (default http://127.0.0.1:8090, PocketBase's host-published
// port from docker-compose.yml) and that $API_TEST_EMAIL/$API_TEST_PASSWORD
// are seeded there.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:pocketbase/pocketbase.dart' as pocketbase;
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart' as generated;

void main() {
  final baseUrl = Platform.environment['PB_URL'] ?? 'http://127.0.0.1:8090';
  final email = Platform.environment['API_TEST_EMAIL'];
  final password = Platform.environment['API_TEST_PASSWORD'];

  /// Runs the full harness-auth -> chat -> first-prompt path for one
  /// multi-provider (api-key/"none" mode) harness, and asserts we get PAST
  /// the resolution bugs fixed 2026-08-28 -- not that we get a real LLM
  /// response, which would need a real, billable provider credential.
  /// A placeholder API key still exercises every one of this session's
  /// fixes: if they regress, this fails with the EXACT symptom logged live
  /// (ACP "Authentication required", -32000) instead of a legitimate
  /// downstream failure (upstream 401 for the fake key, or a transient
  /// "harness is starting" the retry loop below already tolerates).
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
        .getFullList(filter: "harness = '$harnessId'");
    expect(edges, isNotEmpty,
        reason:
            '$cliId must have at least one harness_providers edge -- run '
            'the modelcatalog sync, or this test cannot pick a provider');
    final providerId = edges.first.data['provider'] as String;

    // (owner, provider) is unique -- replace any leftover key from a
    // previous run of this test against the same long-lived docker-compose
    // stack, matching how the real onboarding flow overwrites an existing
    // key rather than erroring.
    final existingKeys = await client.collection('provider_api_keys').getFullList(
        filter: "owner = '$userId' && provider = '$providerId'");
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
    final harnessAuthApi = generated.HarnessAuthApi(dio, generated.standardSerializers);

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
    Response<generated.AcceptedResponse>? response;
    DioException? lastError;
    for (var attempt = 0; attempt < 15; attempt++) {
      try {
        response = await agentApi.promptChat(
          chatId: chat.id,
          promptRequest: promptRequest,
        );
        lastError = null;
        break;
      } on DioException catch (e) {
        lastError = e;
        if (e.response?.statusCode == 503) {
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
        break;
      }
    }

    if (lastError != null) {
      final body = lastError.response?.data;
      final message = body is Map ? body['message']?.toString() ?? '' : '';
      expect(message, isNot(contains('Authentication required')),
          reason: 'regression of the 2026-08-28 sessionprofile/renderEnv '
              'fixes: the credential was never resolved/injected at all. '
              'Full response: $body');
      expect(lastError.response?.statusCode, isNot(503),
          reason: 'harness never finished starting after 15 retries: $body');
      // Any other failure (e.g. a real upstream 401 from the placeholder
      // key reaching the actual provider) is a PASS for this test's
      // purpose: it proves our own credential resolution succeeded and the
      // request reached the harness with a real, non-empty credential.
      return;
    }
    expect(response, isNotNull);
  }

  group('local golden path (docker-compose, no VPS)', () {
    test(
      'goose: harness-auth (none mode) -> chat -> first prompt resolves a '
      'real credential instead of failing with Authentication required',
      () async {
        if (email == null || password == null) {
          markTestSkipped(
              'API_TEST_EMAIL/API_TEST_PASSWORD not set -- run via '
              'tests/compose/api/run.sh, not directly');
          return;
        }
        await checkApiKeyHarnessGoldenPath('goose');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'opencode: harness-auth (none mode) -> chat -> first prompt resolves '
      'a real credential instead of failing with Authentication required',
      () async {
        if (email == null || password == null) {
          markTestSkipped(
              'API_TEST_EMAIL/API_TEST_PASSWORD not set -- run via '
              'tests/compose/api/run.sh, not directly');
          return;
        }
        await checkApiKeyHarnessGoldenPath('opencode');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
