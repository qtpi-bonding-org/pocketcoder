import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:flutter/services.dart';

@module
abstract class ExternalModule {
  @preResolve
  @singleton
  Future<PocketBase> get pocketBase async {
    debugPrint('PocketBaseInit: Starting...');

    // 2. Load Schema (for offline capabilities)
    String? schemaJson;
    try {
      debugPrint('PocketBaseInit: Loading assets/pb_schema.json...');
      schemaJson = await rootBundle.loadString('assets/pb_schema.json');
      debugPrint('PocketBaseInit: Schema loaded (${schemaJson.length} chars)');
    } catch (e) {
      debugPrint(
          'PocketBaseInit: ⚠️ Warning - failed to load schema asset: $e');
    }

    // 3. Initialize PocketBase Drift Client
    final client = $PocketBase.database(
      'http://127.0.0.1:8090',
      requestPolicy: RequestPolicy.cacheAndNetwork,
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
}
