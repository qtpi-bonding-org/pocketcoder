import 'permission_request.dart';

abstract class IPermissionRepository {
  Stream<List<PermissionRequest>> watchPending(String chatId);
  Future<void> authorize(String permissionId);
  Future<void> deny(String permissionId);
}
