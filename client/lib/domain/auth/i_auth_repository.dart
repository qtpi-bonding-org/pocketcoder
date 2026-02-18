import '../ssh/ssh_key.dart';
import '../auth/user.dart';

abstract class IAuthRepository {
  Stream<bool> get connectionStatus;

  Future<bool> login(String email, String password);
  Future<void> logout();
  Future<bool> refreshToken();

  bool get isAuthenticated;
  String? get currentUserId;
  String? get currentUserEmail;
  String? get currentUserRole;

  void updateBaseUrl(String url);

  // --- Users ---
  Future<List<User>> getUsers();

  // --- SSH Keys ---
  Future<List<SshKey>> getSshKeys();
  Future<void> addSshKey(String title, String key);
  Future<void> deleteSshKey(String id);
  Future<String> getSshKeysForAuthorizedKeys();
}
