// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'git_ssh_credential.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GitSshCredential _$GitSshCredentialFromJson(Map<String, dynamic> json) =>
    _GitSshCredential(
      id: json['id'] as String,
      user: json['user'] as String,
      label: json['label'] as String,
      kind: $enumDecode(_$GitSshCredentialKindEnumMap, json['kind'],
          unknownValue: GitSshCredentialKind.unknown),
      source: $enumDecode(_$GitSshCredentialSourceEnumMap, json['source'],
          unknownValue: GitSshCredentialSource.unknown),
      algorithm: $enumDecode(
          _$GitSshCredentialAlgorithmEnumMap, json['algorithm'],
          unknownValue: GitSshCredentialAlgorithm.unknown),
      publicKey: json['public_key'] as String?,
      fingerprint: json['fingerprint'] as String?,
      status: $enumDecode(_$GitSshCredentialStatusEnumMap, json['status'],
          unknownValue: GitSshCredentialStatus.unknown),
      lastError: json['last_error'] as String?,
      materializedGeneration: json['materialized_generation'] as String?,
    );

Map<String, dynamic> _$GitSshCredentialToJson(_GitSshCredential instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user': instance.user,
      'label': instance.label,
      'kind': _$GitSshCredentialKindEnumMap[instance.kind]!,
      'source': _$GitSshCredentialSourceEnumMap[instance.source]!,
      'algorithm': _$GitSshCredentialAlgorithmEnumMap[instance.algorithm]!,
      'public_key': instance.publicKey,
      'fingerprint': instance.fingerprint,
      'status': _$GitSshCredentialStatusEnumMap[instance.status]!,
      'last_error': instance.lastError,
      'materialized_generation': instance.materializedGeneration,
    };

const _$GitSshCredentialKindEnumMap = {
  GitSshCredentialKind.deploy: 'deploy',
  GitSshCredentialKind.account: 'account',
  GitSshCredentialKind.unknown: '__unknown__',
};

const _$GitSshCredentialSourceEnumMap = {
  GitSshCredentialSource.generated: 'generated',
  GitSshCredentialSource.imported: 'imported',
  GitSshCredentialSource.unknown: '__unknown__',
};

const _$GitSshCredentialAlgorithmEnumMap = {
  GitSshCredentialAlgorithm.ed25519: 'ed25519',
  GitSshCredentialAlgorithm.unknown: '__unknown__',
};

const _$GitSshCredentialStatusEnumMap = {
  GitSshCredentialStatus.pending: 'pending',
  GitSshCredentialStatus.materializing: 'materializing',
  GitSshCredentialStatus.ready: 'ready',
  GitSshCredentialStatus.error: 'error',
  GitSshCredentialStatus.retiring: 'retiring',
  GitSshCredentialStatus.unknown: '__unknown__',
};
