import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:flutter/services.dart';

@module
abstract class ExternalModule {
  @preResolve
  @singleton
  Future<PocketBase> get pocketBase async {
    // 1. Get Application Documents Directory for Persistent Storage
    // final docsDir = await getApplicationDocumentsDirectory();
    // final dbPath = p.join(docsDir.path, 'pocketcoder.db');

    // 2. Load Schema (for offline capabilities) - gracefully handle missing schema
    String? schemaJson;
    try {
      schemaJson = await rootBundle.loadString('assets/pb_schema.json');
    } catch (e) {
      // Schema not found (dev mode or first run), offline sync might be limited
      debugPrint(
          '⚠️ Warning: assets/pb_schema.json not found. Offline capability limited.');
    }

    // 3. Initialize PocketBase Drift Client
    final client = $PocketBase.database(
      'http://127.0.0.1:8090',
      requestPolicy: RequestPolicy.cacheAndNetwork,
    );

    if (schemaJson != null && schemaJson.isNotEmpty && schemaJson != '[]') {
      // Only cache if valid schema exists
      await client.cacheSchema(schemaJson);
    }

    return client;
  }
}
