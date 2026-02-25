import 'package:pocketcoder_flutter/domain/models/permission.dart';
import 'package:pocketcoder_flutter/domain/models/whitelist_target.dart';
import 'package:pocketcoder_flutter/domain/models/whitelist_action.dart';
import '../permission/permission_api_models.dart';

abstract class IHitlRepository {
  // --- Permissions ---
  Stream<List<Permission>> watchPending(String chatId);
  Future<void> authorize(String permissionId);
  Future<void> deny(String permissionId);

  /// Evaluate a permission request via the custom endpoint
  Future<PermissionResponse> evaluatePermission({
    required String permission,
    required List<String> patterns,
    required String chatId,
    required String sessionId,
    required String agentPermissionId,
    Map<String, dynamic>? metadata,
    String? message,
    String? messageId,
    String? callId,
  });

  // --- Whitelist ---
  Future<List<WhitelistTarget>> getTargets();
  Future<List<WhitelistAction>> getActions();

  Future<WhitelistTarget> createTarget(String name, String pattern);
  Future<void> deleteTarget(String id);

  Future<WhitelistAction> createAction(
    String permission, {
    String kind = 'pattern',
    String? value,
  });
  Future<void> deleteAction(String id);
  Future<void> toggleAction(String id, bool active);
}
