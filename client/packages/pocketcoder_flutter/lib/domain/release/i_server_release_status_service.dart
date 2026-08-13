import 'server_release_status.dart';

abstract class IServerReleaseStatusService {
  bool get isAuthenticated;

  Stream<bool> get authenticationChanges;

  Future<ServerReleaseStatusSnapshot> inspect();
}
