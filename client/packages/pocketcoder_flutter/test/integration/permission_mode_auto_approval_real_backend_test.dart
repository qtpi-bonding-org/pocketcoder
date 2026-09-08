// Run:
//   docker compose up -d --wait pocketbase
//   POCKETBASE_SUPERUSER_EMAIL=... POCKETBASE_SUPERUSER_PASSWORD=... \
//   PB_URL=http://127.0.0.1:8090 \
//   REAL_PROVIDER_API_KEY=... [REAL_PROVIDER_ID=openrouter] \
//   flutter test test/integration/permission_mode_auto_approval_real_backend_test.dart
import 'dart:async';
import 'dart:io';

import 'package:ag_ui/ag_ui.dart'
    show RunErrorEvent, RunFinishedEvent, RunStartedEvent, StateDeltaEvent;
import 'package:collection/collection.dart';
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

  test(
    'goose: a chat on an agent_profile with an allow-all permission_mode '
    'runs a real tool-using turn with zero permission_request events',
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

      final admin = pocketbase.PocketBase(baseUrl);
      await admin
          .collection('_superusers')
          .authWithPassword(superuserEmail, superuserPassword);
      const email = 'permission-auto-approve-integration-test@pocketcoder.local';
      const password = 'permission-auto-approve-integration-test-pw';
      final existing = await admin
          .collection('users')
          .getFullList(filter: "email = '$email'");
      if (existing.isEmpty) {
        await admin.collection('users').create(body: {
          'email': email,
          'password': password,
          'passwordConfirm': password,
          'role': 'user',
          'verified': true,
        });
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

      final models = await client.collection('models').getFullList(
          filter: "provider = '$providerId' && name = '$realProviderId/auto'");
      expect(models, isNotEmpty,
          reason: 'provider "$realProviderId" has no "$realProviderId/auto" '
              'model in its catalog');
      final modelId = models.first.id;
      final harnessModels = await client.collection('harness_models').getFullList(
          filter: "harness = '$harnessId' && model = '$modelId'");
      expect(harnessModels, isNotEmpty,
          reason: 'goose has no harness_models row for this resolved model');
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

      final existingModes = await client
          .collection('permission_modes')
          .getFullList(filter: "user = '$userId' && name = 'integration-test-allow-all'");
      for (final mode in existingModes) {
        await client.collection('permission_modes').delete(mode.id);
      }
      final permissionMode = await client.collection('permission_modes').create(body: {
        'name': 'integration-test-allow-all',
        'base_session_mode': 'approve',
        'user': userId,
        'is_system': false,
        'is_default': false,
      });
      addTearDown(() => client.collection('permission_modes').delete(permissionMode.id));
      await client.collection('permission_mode_tools').create(body: {
        'permission_mode': permissionMode.id,
        'tool': '*',
        'pattern': '*',
        'action': 'allow',
        'active': true,
      });

      final existingProfiles = await client
          .collection('agent_profiles')
          .getFullList(filter: "user = '$userId' && name = 'integration-test-allow-all-agent'");
      for (final profile in existingProfiles) {
        await client.collection('agent_profiles').delete(profile.id);
      }
      final agentProfile = await client.collection('agent_profiles').create(body: {
        'name': 'integration-test-allow-all-agent',
        'user': userId,
        'permission_mode': permissionMode.id,
      });
      addTearDown(() => client.collection('agent_profiles').delete(agentProfile.id));

      final chat = await client.collection('chats').create(body: {
        'title': 'permission-auto-approve-proof',
        'user': userId,
        'harness': harnessId,
        'harness_model_override': harnessModelId,
        'agent_profile': agentProfile.id,
      });

      final fileName =
          'permission-auto-approve-proof-${DateTime.now().millisecondsSinceEpoch}.txt';

      final apiClient = PocketCoderApiClient(dio: dio);
      final agentApi = apiClient.agent;
      final promptRequest = (generated.PromptRequestBuilder()
            ..prompt.add(generated.ContentBlock((b) => b
              ..type = 'text'
              ..text = 'Using your file tools, create a new file at '
                  '$fileName in your workspace containing exactly the text '
                  '"auto-approved" and nothing else.')))
          .build();

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
        fail('promptChat failed outright (HTTP '
            '${postError.response?.statusCode}): ${postError.response?.data}');
      }
      expect(runId, isNotNull,
          reason: 'promptChat never returned 202 after 15 retries');

      final streamClient =
          AgentStreamClient(pocketBase: client, httpClient: http.Client());
      final frames = streamClient.connect(chat.id, cursor: 0);
      RunErrorEvent? runError;
      var finished = false;
      var runStarted = false;
      final observedPermissionRequestIds = <String>{};
      final done = Completer<void>();
      late final StreamSubscription<StreamFrame> subscription;
      subscription = frames.timeout(const Duration(seconds: 90)).listen(
        (frame) {
          final event = frame.event;
          if (event is RunStartedEvent && event.runId == runId) {
            runStarted = true;
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
              if (requestId != null && status == 'pending') {
                observedPermissionRequestIds.add(requestId);
              }
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

      expect(observedPermissionRequestIds, isEmpty,
          reason: 'expected zero permission_request events with an '
              'allow-all permission_mode wired to this chat\'s '
              'agent_profile, but observed '
              '${observedPermissionRequestIds.length}: PocketBase\'s '
              'permission_mode_tools rule was not honored');

      final error = runError;
      if (error != null) {
        fail('expected the agent to finish writing the file but got '
            'RUN_ERROR (code "${error.code}"): ${error.message}');
      }
      expect(finished, isTrue,
          reason: 'expected RUN_FINISHED for this run before the stream '
              'loop exited');

      final filesApi = generated.FilesApi(dio, generated.standardSerializers);
      final treeResp = await filesApi.listWorkspaceFileTree(path: '.');
      expect(treeResp.statusCode, 200);
      final entries = treeResp.data?.entries.toList() ?? const [];
      final probeEntry = entries.where((e) => e.name == fileName).firstOrNull;
      expect(probeEntry, isNotNull,
          reason: 'listWorkspaceFileTree(".") returned '
              '${entries.map((e) => e.name).toList()}, expected to find the '
              'file the agent was told to write -- the auto-approved tool '
              'call must have actually executed, not just avoided asking.');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
