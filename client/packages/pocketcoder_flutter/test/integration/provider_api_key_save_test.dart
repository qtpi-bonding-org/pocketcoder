// Local (docker-compose, no Linode/VPS) check that saving a provider API
// key actually works through the REAL client-side write path a Settings/
// onboarding screen uses -- ProviderRepository.saveProviderAPIKey backed by
// a real, network-connected $PocketBase (pocketbase_drift) client -- against
// a REAL PocketBase server. Not a mock (see provider_repository_test.dart
// for the mocked-DAO unit test of this same method's branching logic) and
// not a raw REST/curl call: this exercises the exact `$RecordService`/
// `BaseDao.save` machinery the app's own Settings screen calls, so it would
// have caught the 2026-08-28 `hidden: true` field regression (see
// d537fdf3f) that silently stripped every real user's saved key.
//
// Run via tests/compose/api/run.sh (brings up the real docker-compose stack
// first) -- this file alone assumes PocketBase is already reachable at
// $PB_URL (default http://127.0.0.1:8090) and that $API_TEST_EMAIL/
// $API_TEST_PASSWORD are seeded there.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart' as pocketbase;
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';
import 'package:pocketcoder_flutter/infrastructure/provider/provider_daos.dart';
import 'package:pocketcoder_flutter/infrastructure/provider/provider_repository.dart';

void main() {
  // Deliberately NOT TestWidgetsFlutterBinding: that binding fakes/blocks
  // every real dart:io HttpClient request (returns 400 for everything),
  // which would defeat the entire point of this test -- a real network
  // call against the real PocketBase server. $PocketBase (pocketbase_drift)
  // requires SOME WidgetsBinding to exist (it registers itself as a
  // WidgetsBindingObserver), so use the real one instead.
  WidgetsFlutterBinding.ensureInitialized();

  final baseUrl = Platform.environment['PB_URL'] ?? 'http://127.0.0.1:8090';
  final email = Platform.environment['API_TEST_EMAIL'];
  final password = Platform.environment['API_TEST_PASSWORD'];

  test(
      'saveProviderAPIKey persists a real key through the drift-backed '
      'client and it reads back correctly', () async {
    // A plain, non-drift client to authenticate and to independently
    // verify what actually landed server-side, so the assertions below
    // aren't just reading the drift client's own local cache back at
    // itself.
    final verifyClient = pocketbase.PocketBase(baseUrl);
    await verifyClient.collection('users').authWithPassword(email!, password!);
    final userId = verifyClient.authStore.record!.id;
    final token = verifyClient.authStore.token;

    final provider = await verifyClient
        .collection('providers')
        .getFirstListItem('provider_id = "openai"');

    // (owner, provider) is unique -- clear any leftover key from a previous
    // run of this test, matching how a real user re-saving their key
    // overwrites rather than errors.
    final existing = await verifyClient.collection('provider_api_keys').getFullList(
        filter: "owner = '$userId' && provider = '${provider.id}'");
    for (final key in existing) {
      await verifyClient.collection('provider_api_keys').delete(key.id);
    }

    // This is the real client-side write path: a network-connected
    // $PocketBase (drift-backed, exactly what the app constructs at
    // startup) driving ProviderRepository.saveProviderAPIKey, the same
    // method the Settings screen's provider-key dialog calls.
    final store = $AuthStore(save: (_) async {});
    store.save(token, null);
    final client = $PocketBase.database(
      baseUrl,
      inMemory: true,
      authStore: store,
      requestPolicy: RequestPolicy.networkFirst,
    );
    addTearDown(client.close);

    // Mirrors ExternalModule.pocketBase's real startup step (external_module.dart):
    // pocketbase_drift validates writes against a locally-cached collection
    // schema, so a freshly constructed client must load one before any
    // create/update -- otherwise BaseDao.save fails with "Collection schema
    // not found in local database", never reaching the network at all.
    final schemaJson = await rootBundle.loadString('assets/pb_schema.json');
    final decoded = jsonDecode(schemaJson);
    final schemaList = decoded is Map ? decoded['items'] as List<dynamic> : decoded as List<dynamic>;
    await client.cacheSchema(jsonEncode(schemaList));

    final repository = ProviderRepository(
      HarnesseDao(client),
      ModelDao(client),
      HarnessModelDao(client),
      ProviderAPIKeyDao(client),
      HarnessProviderDao(client),
      ProviderCatalogDao(client),
    );

    await repository.saveProviderAPIKey(ProviderApiKey(
      id: '',
      owner: userId,
      provider: provider.id,
      apiKey: 'sk-real-dart-save-flow-check',
    ));

    final saved = await verifyClient
        .collection('provider_api_keys')
        .getFirstListItem("owner = '$userId' && provider = '${provider.id}'");
    expect(saved.data['api_key'], 'sk-real-dart-save-flow-check',
        reason: 'the key saved through ProviderRepository must actually '
            'reach the server with its real value -- this is exactly what '
            "the api_key field's earlier hidden: true regression broke "
            '(the field was silently stripped and the create/update failed '
            '"Cannot be blank" instead)');

    // Re-saving with an empty apiKey on an existing id means "keep the
    // current secret" (ProviderRepository.saveProviderAPIKey's own
    // documented convenience) -- confirm the real server-side value
    // survives that call unchanged rather than being wiped to empty.
    await repository.saveProviderAPIKey(ProviderApiKey(
      id: saved.id,
      owner: userId,
      provider: provider.id,
      apiKey: '',
      baseUrl: 'https://example.invalid',
    ));

    final afterEmptyUpdate =
        await verifyClient.collection('provider_api_keys').getOne(saved.id);
    expect(afterEmptyUpdate.data['api_key'], 'sk-real-dart-save-flow-check',
        reason: 'an empty apiKey on update must keep the existing secret, '
            'not overwrite it with an empty string');
    expect(afterEmptyUpdate.data['base_url'], 'https://example.invalid',
        reason: 'other fields in the same update must still apply');

    await verifyClient.collection('provider_api_keys').delete(saved.id);
  });
}
