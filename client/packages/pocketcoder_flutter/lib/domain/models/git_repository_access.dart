import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'git_repository_access.freezed.dart';
part 'git_repository_access.g.dart';

@freezed
abstract class GitRepositoryAccess with _$GitRepositoryAccess {
  const factory GitRepositoryAccess({
    required String id,
    required String user,
    @JsonKey(unknownEnumValue: GitRepositoryAccessProvider.unknown)
    required GitRepositoryAccessProvider provider,
    required String repository,
    required String purpose,
    @JsonKey(unknownEnumValue: GitRepositoryAccessCredentialMode.unknown)
    required GitRepositoryAccessCredentialMode credentialMode,
    String? credential,
    @JsonKey(unknownEnumValue: GitRepositoryAccessRequestedAccess.unknown)
    required GitRepositoryAccessRequestedAccess requestedAccess,
    @JsonKey(unknownEnumValue: GitRepositoryAccessRegistrationStatus.unknown)
    required GitRepositoryAccessRegistrationStatus registrationStatus,
    @JsonKey(unknownEnumValue: GitRepositoryAccessStatus.unknown)
    required GitRepositoryAccessStatus status,
    String? lastError,
  }) = _GitRepositoryAccess;

  factory GitRepositoryAccess.fromRecord(RecordModel record) =>
      GitRepositoryAccess.fromJson(record.toJson());

  factory GitRepositoryAccess.fromJson(Map<String, dynamic> json) =>
      _$GitRepositoryAccessFromJson(json);
}

enum GitRepositoryAccessProvider {
  @JsonValue('github')
  github,
  @JsonValue('gitlab')
  gitlab,
  @JsonValue('codeberg')
  codeberg,
  @JsonValue('__unknown__')
  unknown,
}

enum GitRepositoryAccessCredentialMode {
  @JsonValue('generated_deploy')
  generatedDeploy,
  @JsonValue('existing_account')
  existingAccount,
  @JsonValue('__unknown__')
  unknown,
}

enum GitRepositoryAccessRequestedAccess {
  @JsonValue('read_only')
  readOnly,
  @JsonValue('read_write')
  readWrite,
  @JsonValue('__unknown__')
  unknown,
}

enum GitRepositoryAccessRegistrationStatus {
  @JsonValue('needs_registration')
  needsRegistration,
  @JsonValue('registered')
  registered,
  @JsonValue('revoked')
  revoked,
  @JsonValue('__unknown__')
  unknown,
}

enum GitRepositoryAccessStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('ready')
  ready,
  @JsonValue('error')
  error,
  @JsonValue('__unknown__')
  unknown,
}
