import 'package:flutter_aeroform/domain/models/provision_session.dart';
import 'package:flutter_aeroform/domain/storage/i_secure_storage.dart';

sealed class ResumeOutcome {}

final class ProvisionResume extends ResumeOutcome {}

final class DeploymentResume extends ResumeOutcome {}

final class NothingToResume extends ResumeOutcome {}

class PocketCoderSessionStore {
  PocketCoderSessionStore(this._storage);
  final ISecureStorage _storage;

  Future<void> store(ProvisionSession session) =>
      _storage.storeProvisionSession(session);

  Future<ProvisionSession?> load() => _storage.getProvisionSession();

  Future<void> clear(String sessionId) async {
    final current = await load();
    if (current?.sessionId == sessionId) {
      await _storage.clearProvisionSession(sessionId);
    }
  }
}
