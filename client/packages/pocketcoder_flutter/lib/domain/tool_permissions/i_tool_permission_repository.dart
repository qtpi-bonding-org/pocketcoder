import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';

abstract class IToolPermissionRepository {
  Stream<List<ToolPermission>> watchRules();
  Future<void> createRule({required String tool, required String action});
  Future<void> updateAction(String id, String action);
  Future<void> setActive(String id, bool active);
}
