import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/auth/user.dart';
import 'package:pocketcoder_flutter/domain/models/ssh_key.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';
import 'package:pocketcoder_flutter/infrastructure/core/collections.dart';

@lazySingleton
class UserDao extends BaseDao<User> {
  UserDao(PocketBase pb) : super(pb, Collections.users, User.fromJson);
}

@lazySingleton
class SshKeyDao extends BaseDao<SshKey> {
  SshKeyDao(PocketBase pb) : super(pb, Collections.sshKeys, SshKey.fromJson);
}
