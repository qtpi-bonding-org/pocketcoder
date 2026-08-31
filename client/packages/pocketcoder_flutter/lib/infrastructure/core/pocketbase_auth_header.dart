import 'package:pocketbase_drift/pocketbase_drift.dart';

/// The `Authorization` header value PocketBase (and every custom
/// `/api/pocketcoder/v1/*` endpoint, per its `pocketbaseToken` OpenAPI
/// security scheme) expects: the raw token, with NO `Bearer ` prefix. Null
/// when there is no current session -- callers must decide explicitly
/// whether that means "omit the header" or "this operation requires auth,
/// fail now," rather than silently sending an empty Authorization value.
String? pocketBaseAuthHeaderValue(PocketBase pb) {
  final token = pb.authStore.token;
  return token.isEmpty ? null : token;
}
