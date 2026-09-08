import 'package:pocketcoder_flutter/domain/models/git_repository_access.dart';
import 'package:pocketcoder_flutter/domain/models/git_ssh_credential.dart';

abstract interface class IGitSshRepository {
  Stream<List<GitSshCredential>> watchCredentials();

  Stream<List<GitRepositoryAccess>> watchAccess();

  Future<void> createAccountKey(String label);

  Future<void> addRepositoryAccess({
    required GitRepositoryAccessProvider provider,
    required String repository,
    required String purpose,
    required GitRepositoryAccessCredentialMode credentialMode,
    required GitRepositoryAccessRequestedAccess requestedAccess,
    String? credential,
    String? host,
    int? port,
  });

  Future<void> deleteAccess(String accessId);
}
