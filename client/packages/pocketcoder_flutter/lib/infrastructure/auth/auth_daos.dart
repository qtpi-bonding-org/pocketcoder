import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../domain/auth/user.dart';
import '../../domain/ssh/ssh_key.dart';
import '../core/base_dao.dart';
import '../core/collections.dart';

@lazySingleton
class UserDao extends BaseDao<User> {
  UserDao(PocketBase pb) : super(pb, Collections.users, User.fromJson);
}

@lazySingleton
class SshKeyDao extends BaseDao<SshKey> {
  SshKeyDao(PocketBase pb) : super(pb, Collections.sshKeys, SshKey.fromJson);
}
