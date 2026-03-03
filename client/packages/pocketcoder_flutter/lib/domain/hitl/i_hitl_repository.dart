import 'package:pocketcoder_flutter/domain/models/permission.dart';
import 'package:pocketcoder_flutter/domain/models/question.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import '../permission/permission_api_models.dart';

abstract class IHitlRepository {
  // --- Permissions ---
  Stream<List<Permission>> watchPending(String chatId);
  Future<void> authorize(String permissionId);
  Future<void> deny(String permissionId);

  // --- Questions ---
  Stream<List<Question>> watchQuestions(String chatId);
  Future<void> answerQuestion(String questionId, String reply);
  Future<void> rejectQuestion(String questionId);

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

  // --- Tool Permissions ---
  Future<List<ToolPermission>> getToolPermissions();
  Future<ToolPermission> createToolPermission({
    String? agent,
    required String tool,
    required String pattern,
    required String action,
  });
  Future<void> deleteToolPermission(String id);
  Future<void> toggleToolPermission(String id, bool active);
}
