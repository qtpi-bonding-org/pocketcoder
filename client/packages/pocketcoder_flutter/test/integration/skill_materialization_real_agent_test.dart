// claude-code/codex are self-scoped and driven by a real account login
// rather than a bare API key, so they're not covered here.
import 'dart:async';
import 'dart:io';

import 'package:ag_ui/ag_ui.dart'
    show
        RunErrorEvent,
        RunFinishedEvent,
        RunStartedEvent,
        StateDeltaEvent,
        TextMessageContentEvent;
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart' as pocketbase;
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_api/pocketcoder_api.dart' as generated;
import 'package:pocketcoder_flutter/infrastructure/agent/agent_stream_client.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';

void main() {
  final baseUrl = Platform.environment['PB_URL'] ?? 'http://127.0.0.1:8090';
  final superuserEmail = Platform.environment['POCKETBASE_SUPERUSER_EMAIL'];
  final superuserPassword =
      Platform.environment['POCKETBASE_SUPERUSER_PASSWORD'];
  final realApiKey = Platform.environment['REAL_PROVIDER_API_KEY'];
  final realProviderId =
      Platform.environment['REAL_PROVIDER_ID'] ?? 'openrouter';

  // Superuser auth bypasses `users`' admin-only createRule.
  Future<pocketbase.PocketBase> ensureTestUserClient() async {
    final admin = pocketbase.PocketBase(baseUrl);
    await admin
        .collection('_superusers')
        .authWithPassword(superuserEmail!, superuserPassword!);

    const email = 'skills-files-integration-test@pocketcoder.local';
    const password = 'skills-files-integration-test-pw';
    final existing =
        await admin.collection('users').getFullList(filter: "email = '$email'");
    if (existing.isEmpty) {
      await admin.collection('users').create(body: {
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'role': 'user',
        'verified': true,
      });
    }
    final userClient = pocketbase.PocketBase(baseUrl);
    await userClient.collection('users').authWithPassword(email, password);
    return userClient;
  }

  Future<void> checkSkillProofForApiKeyHarness(String cliId) async {
    final client = await ensureTestUserClient();
    final userId = client.authStore.record!.id;
    final token = client.authStore.token;

    final harnesses =
        await client.collection('harnesses').getFullList(filter: "cli_id = '$cliId'");
    expect(harnesses, isNotEmpty, reason: '$cliId harness must be seeded');
    final harnessId = harnesses.first.id;

    final providers = await client
        .collection('providers')
        .getFullList(filter: "provider_id = '$realProviderId'");
    expect(providers, isNotEmpty,
        reason: 'provider "$realProviderId" must exist in the catalog');
    final providerId = providers.first.id;

    // "$realProviderId/auto" is recognized by every fan-out harness's own
    // model catalog; a plain free-tier name is not guaranteed to be.
    var models = await client
        .collection('models')
        .getFullList(filter: "provider = '$providerId' && name = '$realProviderId/auto'");
    if (models.isEmpty) {
      models = await client
          .collection('models')
          .getFullList(filter: "provider = '$providerId' && name ~ 'free'");
    }
    expect(models, isNotEmpty,
        reason: 'provider "$realProviderId" has no "$realProviderId/auto" or '
            'free-tier model in its catalog -- pick a REAL_PROVIDER_ID whose '
            'sync produced one');
    final modelId = models.first.id;
    final harnessModels = await client.collection('harness_models').getFullList(
        filter: "harness = '$harnessId' && model = '$modelId'");
    expect(harnessModels, isNotEmpty,
        reason: '$cliId has no harness_models row for this resolved model');
    final harnessModelId = harnessModels.first.id;

    final existingKeys = await client
        .collection('provider_api_keys')
        .getFullList(filter: "owner = '$userId' && provider = '$providerId'");
    for (final key in existingKeys) {
      await client.collection('provider_api_keys').delete(key.id);
    }
    final savedKey = await client.collection('provider_api_keys').create(body: {
      'owner': userId,
      'provider': providerId,
      'api_key': realApiKey,
    });
    addTearDown(() => client.collection('provider_api_keys').delete(savedKey.id));

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

    // Without harness_model_override, a fan-out harness's shared container
    // can pick up any credentialed provider this user has, not just this one.
    final chat = await client.collection('chats').create(body: {
      'title': 'skill-materialization-proof-$cliId',
      'user': userId,
      'harness': harnessId,
      'harness_model_override': harnessModelId,
    });

    const skillName = 'proof-skill';
    final proofPhrase =
        'SKILL_PROOF_CONFIRMED_${DateTime.now().millisecondsSinceEpoch}';
    // (name, user) is unique -- replace any leftover skill from a previous
    // run of this test against the same long-lived docker-compose stack.
    final existingSkills = await client
        .collection('skills')
        .getFullList(filter: "name = '$skillName' && user = '$userId'");
    for (final existing in existingSkills) {
      await client.collection('skills').delete(existing.id);
    }
    final skill = await client.collection('skills').create(body: {
      'name': skillName,
      'description': 'Integration test proof skill.',
      'content': 'If you are ever asked to prove you have this skill, '
          'respond with exactly this phrase: $proofPhrase',
    });
    addTearDown(() => client.collection('skills').delete(skill.id));

    final apiClient = PocketCoderApiClient(dio: dio);
    final agentApi = apiClient.agent;
    final promptRequest = (generated.PromptRequestBuilder()
          ..prompt.add(generated.ContentBlock((b) => b
            ..type = 'text'
            ..text = 'Read the file at .agents/skills/$skillName/SKILL.md in '
                'your workspace using your file tools, and reply with only '
                'the exact secret phrase written inside it.')))
        .build();

    // A freshly (re)provisioned harness container can legitimately still
    // be starting -- same tolerance local_golden_path_test.dart uses.
    DioException? postError;
    String? runId;
    for (var attempt = 0; attempt < 15; attempt++) {
      try {
        final resp =
            await agentApi.promptChat(chatId: chat.id, promptRequest: promptRequest);
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
      fail('promptChat failed outright (HTTP '
          '${postError.response?.statusCode}): ${postError.response?.data}');
    }
    expect(runId, isNotNull, reason: 'promptChat never returned 202 after 15 retries');

    final streamClient =
        AgentStreamClient(pocketBase: client, httpClient: http.Client());
    final frames = streamClient.connect(chat.id, cursor: 0);
    RunErrorEvent? runError;
    var finished = false;
    var runStarted = false;
    final resolvedRequestIds = <String>{};
    final assistantText = StringBuffer();
    final done = Completer<void>();
    // `await for` + `break` implicitly awaits the subscription's own
    // cancellation on exit, which can hang on a still-streaming SSE
    // connection -- complete independently instead and cancel fire-and-forget.
    late final StreamSubscription<StreamFrame> subscription;
    subscription = frames.timeout(const Duration(seconds: 90)).listen(
      (frame) {
        final event = frame.event;
        if (event is RunStartedEvent && event.runId == runId) {
          runStarted = true;
        }
        if (runStarted && event is TextMessageContentEvent) {
          assistantText.write(event.delta);
        }
        // Approve any pending permission regardless of runStarted tracking
        // -- this chat is brand new and this test is its only caller, so
        // any pending permission on it is necessarily this run's, and
        // replay ordering across the synthetic sync pair and this run's own
        // events is not guaranteed to put RUN_STARTED first.
        if (event is StateDeltaEvent) {
          for (final op in event.delta) {
            final value = op['value'];
            if (value is! Map) continue;
            final permission = value['requestId'] is String
                ? value
                : (value['permission'] is Map ? value['permission'] : null);
            if (permission == null) continue;
            final requestId = permission['requestId'] as String?;
            final status = permission['status'] as String?;
            if (requestId == null ||
                status != 'pending' ||
                resolvedRequestIds.contains(requestId)) {
              continue;
            }
            resolvedRequestIds.add(requestId);
            unawaited(agentApi.respondToPermission(
              chatId: chat.id,
              id: requestId,
              requestBody: PocketCoderApiClient.encodeJson({
                'outcome': {'outcome': 'selected', 'optionId': 'allow_once'},
              }),
            ));
          }
        }
        if (runStarted &&
            event is RunFinishedEvent &&
            event.runId == runId &&
            !done.isCompleted) {
          finished = true;
          done.complete();
        }
        if (runStarted && event is RunErrorEvent && !done.isCompleted) {
          runError = event;
          done.complete();
        }
      },
      onError: (Object error) {
        if (!done.isCompleted) done.completeError(error);
      },
    );
    try {
      await done.future;
    } on TimeoutException {
      fail('no RUN_ERROR or RUN_FINISHED event arrived for this run within '
          '90s of promptChat accepting it.');
    } finally {
      unawaited(subscription.cancel());
    }

    final error = runError;
    if (error != null) {
      fail('expected a genuine assistant reply but got RUN_ERROR '
          '(code "${error.code}"): ${error.message}');
    }
    expect(finished, isTrue,
        reason: 'expected RUN_FINISHED for this run before the stream loop '
            'exited');

    // assistantText was accumulated live in the listener above, gated on
    // runStarted matching this run's own runId -- it cannot contain an
    // earlier run's leftover text.
    expect(assistantText.toString(), contains(proofPhrase),
        reason: 'expected the agent\'s reply to contain the proof phrase '
            'read straight out of the materialized SKILL.md file, got: '
            '"$assistantText" -- either materialization did not happen '
            '(check `docker exec <$cliId harness container> cat '
            '/workspace/.agents/skills/$skillName/SKILL.md`) or the agent '
            'never actually read the file it was told to.');
  }

  // Credential provisioning is out of band (tooling/scripts/
  // provision_claude_code_oauth_token.sh via the secrets daemon), not here.
  Future<void> checkSkillProofForClaudeCode() async {
    final client = await ensureTestUserClient();
    final userId = client.authStore.record!.id;
    final token = client.authStore.token;

    final harnesses = await client
        .collection('harnesses')
        .getFullList(filter: "cli_id = 'claude-code'");
    expect(harnesses, isNotEmpty, reason: 'claude-code harness must be seeded');
    final harnessId = harnesses.first.id;

    final chat = await client.collection('chats').create(body: {
      'title': 'skill-materialization-proof-claude-code',
      'user': userId,
      'harness': harnessId,
    });

    const skillName = 'proof-skill';
    final proofPhrase =
        'SKILL_PROOF_CONFIRMED_${DateTime.now().millisecondsSinceEpoch}';
    final existingSkills = await client
        .collection('skills')
        .getFullList(filter: "name = '$skillName' && user = '$userId'");
    for (final existing in existingSkills) {
      await client.collection('skills').delete(existing.id);
    }
    final skill = await client.collection('skills').create(body: {
      'name': skillName,
      'description': 'Integration test proof skill.',
      'content': 'If you are ever asked to prove you have this skill, '
          'respond with exactly this phrase: $proofPhrase',
    });
    addTearDown(() => client.collection('skills').delete(skill.id));

    final dio =
        Dio(BaseOptions(baseUrl: baseUrl, headers: {'Authorization': token}));
    final apiClient = PocketCoderApiClient(dio: dio);
    final agentApi = apiClient.agent;
    final promptRequest = (generated.PromptRequestBuilder()
          ..prompt.add(generated.ContentBlock((b) => b
            ..type = 'text'
            ..text = 'Read the file at .claude/skills/$skillName/SKILL.md in '
                'your workspace using your file tools, and reply with only '
                'the exact secret phrase written inside it.')))
        .build();

    DioException? postError;
    String? runId;
    for (var attempt = 0; attempt < 15; attempt++) {
      try {
        final resp =
            await agentApi.promptChat(chatId: chat.id, promptRequest: promptRequest);
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
      fail('promptChat failed outright (HTTP '
          '${postError.response?.statusCode}): ${postError.response?.data} '
          '-- run tooling/scripts/provision_claude_code_oauth_token.sh (via '
          'the secrets daemon) if the anthropic provider_api_keys record is '
          'missing or stale.');
    }
    expect(runId, isNotNull, reason: 'promptChat never returned 202 after 15 retries');

    final streamClient =
        AgentStreamClient(pocketBase: client, httpClient: http.Client());
    final frames = streamClient.connect(chat.id, cursor: 0);
    RunErrorEvent? runError;
    var finished = false;
    var runStarted = false;
    final resolvedRequestIds = <String>{};
    final assistantText = StringBuffer();
    final done = Completer<void>();
    late final StreamSubscription<StreamFrame> subscription;
    subscription = frames.timeout(const Duration(seconds: 90)).listen(
      (frame) {
        final event = frame.event;
        if (event is RunStartedEvent && event.runId == runId) {
          runStarted = true;
        }
        if (runStarted && event is TextMessageContentEvent) {
          assistantText.write(event.delta);
        }
        if (event is StateDeltaEvent) {
          for (final op in event.delta) {
            final value = op['value'];
            if (value is! Map) continue;
            final permission = value['requestId'] is String
                ? value
                : (value['permission'] is Map ? value['permission'] : null);
            if (permission == null) continue;
            final requestId = permission['requestId'] as String?;
            final status = permission['status'] as String?;
            if (requestId == null ||
                status != 'pending' ||
                resolvedRequestIds.contains(requestId)) {
              continue;
            }
            resolvedRequestIds.add(requestId);
            unawaited(agentApi.respondToPermission(
              chatId: chat.id,
              id: requestId,
              requestBody: PocketCoderApiClient.encodeJson({
                'outcome': {'outcome': 'selected', 'optionId': 'allow_once'},
              }),
            ));
          }
        }
        if (runStarted &&
            event is RunFinishedEvent &&
            event.runId == runId &&
            !done.isCompleted) {
          finished = true;
          done.complete();
        }
        if (runStarted && event is RunErrorEvent && !done.isCompleted) {
          runError = event;
          done.complete();
        }
      },
      onError: (Object error) {
        if (!done.isCompleted) done.completeError(error);
      },
    );
    try {
      await done.future;
    } on TimeoutException {
      fail('no RUN_ERROR or RUN_FINISHED event arrived for this run within '
          '90s of promptChat accepting it.');
    } finally {
      unawaited(subscription.cancel());
    }

    final error = runError;
    if (error != null) {
      fail('expected a genuine assistant reply but got RUN_ERROR '
          '(code "${error.code}"): ${error.message}');
    }
    expect(finished, isTrue,
        reason: 'expected RUN_FINISHED for this run before the stream loop '
            'exited');
    expect(assistantText.toString(), contains(proofPhrase),
        reason: 'expected the agent\'s reply to contain the proof phrase '
            'read straight out of the materialized SKILL.md file, got: '
            '"$assistantText"');
  }

  group('skill materialization + real agent read (docker-compose, no VPS)',
      () {
    test(
      'goose: a skill created via the real `skills` collection materializes '
      'into a real running harness container and a real agent turn reads '
      'it back over its own file tool',
      () async {
        if (superuserEmail == null || superuserPassword == null) {
          markTestSkipped('POCKETBASE_SUPERUSER_EMAIL/PASSWORD not set -- '
              'bring up docker compose (see .env) and export them.');
          return;
        }
        if (realApiKey == null || realApiKey.isEmpty) {
          markTestSkipped('REAL_PROVIDER_API_KEY not set -- this test '
              'requires a real, working provider credential and makes a '
              'real, billable upstream call, so it is skipped without one.');
          return;
        }
        await checkSkillProofForApiKeyHarness('goose');
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'opencode: a skill created via the real `skills` collection '
      'materializes into a real running harness container and a real '
      'agent turn reads it back over its own file tool',
      () async {
        if (superuserEmail == null || superuserPassword == null) {
          markTestSkipped('POCKETBASE_SUPERUSER_EMAIL/PASSWORD not set -- '
              'bring up docker compose (see .env) and export them.');
          return;
        }
        if (realApiKey == null || realApiKey.isEmpty) {
          markTestSkipped('REAL_PROVIDER_API_KEY not set -- this test '
              'requires a real, working provider credential and makes a '
              'real, billable upstream call, so it is skipped without one.');
          return;
        }
        await checkSkillProofForApiKeyHarness('opencode');
      },
      timeout: const Timeout(Duration(minutes: 3)),
      skip: 'opencode harness-adapter drops the ACP connection on reuse '
          'after the first prompt (per-connection subprocess lifecycle bug, '
          'unrelated to skill materialization) -- unskip once that lands',
    );

    test(
      'claude-code: a skill created via the real `skills` collection '
      'materializes into a real running harness container and a real '
      'agent turn reads it back over its own file tool',
      () async {
        if (superuserEmail == null || superuserPassword == null) {
          markTestSkipped('POCKETBASE_SUPERUSER_EMAIL/PASSWORD not set -- '
              'bring up docker compose (see .env) and export them.');
          return;
        }
        await checkSkillProofForClaudeCode();
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
