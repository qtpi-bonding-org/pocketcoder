import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'git_ssh_credential.freezed.dart';
part 'git_ssh_credential.g.dart';

@freezed
abstract class GitSshCredential with _$GitSshCredential {
  const factory GitSshCredential({
    required String id,
    required String user,
    required String label,
    @JsonKey(unknownEnumValue: GitSshCredentialKind.unknown)
    required GitSshCredentialKind kind,
    @JsonKey(unknownEnumValue: GitSshCredentialSource.unknown)
    required GitSshCredentialSource source,
    @JsonKey(unknownEnumValue: GitSshCredentialAlgorithm.unknown)
    required GitSshCredentialAlgorithm algorithm,
    String? publicKey,
    String? fingerprint,
    @JsonKey(unknownEnumValue: GitSshCredentialStatus.unknown)
    required GitSshCredentialStatus status,
    String? lastError,
    String? materializedGeneration,
  }) = _GitSshCredential;

  factory GitSshCredential.fromRecord(RecordModel record) =>
      GitSshCredential.fromJson(record.toJson());

  factory GitSshCredential.fromJson(Map<String, dynamic> json) =>
      _$GitSshCredentialFromJson(json);
}

enum GitSshCredentialKind {
  @JsonValue('deploy')
  deploy,
  @JsonValue('account')
  account,
  @JsonValue('__unknown__')
  unknown,
}

enum GitSshCredentialSource {
  @JsonValue('generated')
  generated,
  @JsonValue('imported')
  imported,
  @JsonValue('__unknown__')
  unknown,
}

enum GitSshCredentialAlgorithm {
  @JsonValue('ed25519')
  ed25519,
  @JsonValue('__unknown__')
  unknown,
}

enum GitSshCredentialStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('materializing')
  materializing,
  @JsonValue('ready')
  ready,
  @JsonValue('error')
  error,
  @JsonValue('retiring')
  retiring,
  @JsonValue('__unknown__')
  unknown,
}
