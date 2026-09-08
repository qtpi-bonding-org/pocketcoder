import 'package:pocketcoder_flutter/domain/models/permission_mode.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';

abstract class IPermissionModeRepository {
  /// Every permission mode visible to the current user (system presets +
  /// their own), sorted by name.
  Stream<List<PermissionMode>> watchModes();

  /// The rules belonging to one specific permission mode, sorted by tool.
  Stream<List<ToolPermission>> watchRules(String modeId);

  /// Creates (if [mode.id] is empty) or updates a permission mode's
  /// metadata (name, description, baseSessionMode). Never touches its rules.
  Future<void> saveMode(PermissionMode mode);

  Future<void> deleteMode(String id);

  /// Creates a new personal permission mode named [newName], copying every
  /// active-or-not rule from [source] onto it. Works identically whether
  /// [source] is a system preset or one of the user's own modes.
  Future<void> duplicateMode({
    required PermissionMode source,
    required String newName,
  });

  Future<void> createRule({
    required String modeId,
    required String tool,
    required String action,
  });

  Future<void> updateAction(String id, String action);

  Future<void> setActive(String id, bool active);
}
