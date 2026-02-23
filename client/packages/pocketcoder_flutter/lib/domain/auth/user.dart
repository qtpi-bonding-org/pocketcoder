import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String email,
    String? name,
    String? avatar,
    UserRole? role,
    DateTime? created,
    DateTime? updated,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

enum UserRole {
  @JsonValue('admin')
  admin,
  @JsonValue('agent')
  agent,
  @JsonValue('user')
  user,
  @JsonValue('')
  unknown,
}
