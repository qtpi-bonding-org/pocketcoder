import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/git_ssh/i_git_ssh_repository.dart';
import 'package:pocketcoder_flutter/domain/models/git_repository_access.dart';
import 'package:pocketcoder_flutter/domain/models/git_ssh_credential.dart';
import 'git_ssh_daos.dart';

@LazySingleton(as: IGitSshRepository)
class GitSshRepository implements IGitSshRepository {
  final GitSshCredentialDao _credentialDao;
  final GitRepositoryAccessDao _accessDao;
  final PocketBase _pb;

  GitSshRepository(this._credentialDao, this._accessDao, this._pb);

  // Required by the collections' own create rules (evaluated against the
  // submitted payload, not the record the hook later overwrites it onto).
  String get _ownUserId => requireNonNull(
      _pb.authStore.record?.id, 'authenticated user id', GitSshException.new);

  @override
  Stream<List<GitSshCredential>> watchCredentials() =>
      _credentialDao.watch(sort: '-created');

  @override
  Stream<List<GitRepositoryAccess>> watchAccess() =>
      _accessDao.watch(sort: '-created');

  @override
  Future<void> createAccountKey(String label) async {
    return tryMethod(
      () async {
        await _credentialDao.save(null, {
          'user': _ownUserId,
          'label': label,
          'kind': 'account',
          'source': 'generated',
          'algorithm': 'ed25519',
        });
      },
      GitSshException.new,
      'createAccountKey',
    );
  }

  @override
  Future<void> addRepositoryAccess({
    required GitRepositoryAccessProvider provider,
    required String repository,
    required String purpose,
    required GitRepositoryAccessCredentialMode credentialMode,
    required GitRepositoryAccessRequestedAccess requestedAccess,
    String? credential,
    String? host,
    int? port,
  }) async {
    return tryMethod(
      () async {
        await _accessDao.save(null, {
          'user': _ownUserId,
          'provider': _providerValue(provider),
          'repository': repository,
          'purpose': purpose,
          'credential_mode': _credentialModeValue(credentialMode),
          'requested_access': _requestedAccessValue(requestedAccess),
          if (credential != null) 'credential': credential,
          if (host != null) 'host': host,
          if (port != null) 'port': port,
        });
      },
      GitSshException.new,
      'addRepositoryAccess',
    );
  }

  @override
  Future<void> markRegistered(String accessId) async {
    return tryMethod(
      () async {
        await _accessDao.save(accessId, {'registration_status': 'registered'});
      },
      GitSshException.new,
      'markRegistered',
    );
  }

  @override
  Future<void> deleteAccess(String accessId) async {
    return tryMethod(
      () async {
        await _accessDao.delete(accessId);
      },
      GitSshException.new,
      'deleteAccess',
    );
  }

  String _providerValue(GitRepositoryAccessProvider provider) =>
      switch (provider) {
        GitRepositoryAccessProvider.github => 'github',
        GitRepositoryAccessProvider.gitlab => 'gitlab',
        GitRepositoryAccessProvider.codeberg => 'codeberg',
        GitRepositoryAccessProvider.custom => 'custom',
        GitRepositoryAccessProvider.unknown => 'custom',
      };

  String _credentialModeValue(GitRepositoryAccessCredentialMode mode) =>
      switch (mode) {
        GitRepositoryAccessCredentialMode.generatedDeploy => 'generated_deploy',
        GitRepositoryAccessCredentialMode.existingAccount => 'existing_account',
        GitRepositoryAccessCredentialMode.unknown => 'generated_deploy',
      };

  String _requestedAccessValue(GitRepositoryAccessRequestedAccess access) =>
      switch (access) {
        GitRepositoryAccessRequestedAccess.readOnly => 'read_only',
        GitRepositoryAccessRequestedAccess.readWrite => 'read_write',
        GitRepositoryAccessRequestedAccess.unknown => 'read_only',
      };
}
