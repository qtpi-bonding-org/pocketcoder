import 'package:pocketbase/pocketbase.dart';

abstract class IAuthRepository {
  Stream<bool> get connectionStatus;

  Future<bool> login(String email, String password);
  Future<void> logout();
  Future<bool> refreshToken();

  bool get isAuthenticated;
  String? get currentUserId;
  String? get currentUserEmail;
  String? get currentUserRole;

  Future<bool> approvePermission(String permissionId);
  Future<bool> healthCheck();
  void updateBaseUrl(String url);
}
