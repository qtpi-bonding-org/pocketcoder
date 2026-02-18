import 'whitelist_target.dart';
import 'whitelist_action.dart';

abstract class IWhitelistRepository {
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
