import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_store.dart';
import 'package:test_app/infrastructure/repositories/user_repository.dart';
import 'package:test_app/infrastructure/repositories/ai_model_repository.dart';
import 'package:test_app/infrastructure/repositories/ssh_key_repository.dart';
import 'package:test_app/infrastructure/repositories/proposal_repository.dart';
import 'package:test_app/infrastructure/repositories/subagent_repository.dart';
import 'package:test_app/infrastructure/repositories/whitelist_repository.dart';
import 'package:test_app/infrastructure/services/permission_service.dart';
import 'package:test_app/infrastructure/services/session_service.dart';
import 'package:test_app/infrastructure/services/artifact_service.dart';

@module
abstract class ExternalModule {
  @preResolve
  @singleton
  Future<PocketBase> get pocketBase async {
    debugPrint('PocketBaseInit: Starting...');

    // Determine base URL based on environment
    const baseUrl = kDebugMode ? 'http://127.0.0.1:8090' : 'http://pocketbase:8090';
    debugPrint('PocketBaseInit: Using URL: $baseUrl');

    // Load Schema (for offline capabilities)
    String? schemaJson;
    try {
      debugPrint('PocketBaseInit: Loading assets/pb_schema.json...');
      schemaJson = await rootBundle.loadString('assets/pb_schema.json');
      debugPrint('PocketBaseInit: Schema loaded (${schemaJson.length} chars)');
    } catch (e) {
      debugPrint('PocketBaseInit: ⚠️ Warning - failed to load schema asset: $e');
    }

    // Create secure auth store with flutter_secure_storage
    const storage = FlutterSecureStorage();
    final authStoreConfig = AuthStoreConfig(storage);
    final authStore = authStoreConfig.createAuthStore();

    // Initialize PocketBase Drift Client with persistent auth
    final client = $PocketBase.database(
      baseUrl,
      requestPolicy: RequestPolicy.cacheAndNetwork,
      authStore: authStore,
    );

    if (schemaJson != null && schemaJson.isNotEmpty && schemaJson != '[]') {
      try {
        debugPrint('PocketBaseInit: Caching schema...');
        await client.cacheSchema(schemaJson);
        debugPrint('PocketBaseInit: Schema cached successfully');
      } catch (e) {
        debugPrint('PocketBaseInit: ❌ Error caching schema: $e');
      }
    } else {
      debugPrint('PocketBaseInit: ⚠️ No valid schema found to cache');
    }

    debugPrint('PocketBaseInit: Complete');
    return client;
  }

  @singleton
  AuthStoreConfig get authStoreConfig {
    return AuthStoreConfig(const FlutterSecureStorage());
  }

  // Repositories
  @singleton
  IUserRepository userRepository(PocketBase pocketBase) =>
      UserRepository(pocketBase);

  @singleton
  IAiModelRepository aiModelRepository(PocketBase pocketBase) =>
      AiModelRepository(pocketBase);

  @singleton
  ISSHKeyRepository sshKeyRepository(PocketBase pocketBase) =>
      SSHKeyRepository(pocketBase);

  @singleton
  IProposalRepository proposalRepository(PocketBase pocketBase) =>
      ProposalRepository(pocketBase);

  @singleton
  ISubagentRepository subagentRepository(PocketBase pocketBase) =>
      SubagentRepository(pocketBase);

  @singleton
  IWhitelistRepository whitelistRepository(PocketBase pocketBase) =>
      WhitelistRepository(pocketBase);

  // Services
  @singleton
  IPermissionService permissionService(PocketBase pocketBase) =>
      PermissionService(pocketBase);

  @singleton
  ISessionService sessionService(PocketBase pocketBase) =>
      SessionService(pocketBase);

  @singleton
  IArtifactService artifactService(PocketBase pocketBase) =>
      ArtifactService(pocketBase);
}
