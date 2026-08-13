import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/collections.dart';
import 'package:pocketcoder_flutter/domain/models/git_repository_access.dart';
import 'package:pocketcoder_flutter/domain/models/git_ssh_credential.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';

@lazySingleton
class GitSshCredentialDao extends BaseDao<GitSshCredential> {
  GitSshCredentialDao(PocketBase pb)
    : super(pb, Collections.gitSshCredentials, GitSshCredential.fromJson);
}

@lazySingleton
class GitRepositoryAccessDao extends BaseDao<GitRepositoryAccess> {
  GitRepositoryAccessDao(PocketBase pb)
    : super(pb, Collections.gitRepositoryAccess, GitRepositoryAccess.fromJson);
}
