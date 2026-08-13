// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'git_repository_access.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GitRepositoryAccess _$GitRepositoryAccessFromJson(Map<String, dynamic> json) =>
    _GitRepositoryAccess(
      id: json['id'] as String,
      user: json['user'] as String,
      provider: $enumDecode(
          _$GitRepositoryAccessProviderEnumMap, json['provider'],
          unknownValue: GitRepositoryAccessProvider.unknown),
      repository: json['repository'] as String,
      purpose: json['purpose'] as String,
      credentialMode: $enumDecode(
          _$GitRepositoryAccessCredentialModeEnumMap, json['credential_mode'],
          unknownValue: GitRepositoryAccessCredentialMode.unknown),
      credential: json['credential'] as String?,
      requestedAccess: $enumDecode(
          _$GitRepositoryAccessRequestedAccessEnumMap, json['requested_access'],
          unknownValue: GitRepositoryAccessRequestedAccess.unknown),
      registrationStatus: $enumDecode(
          _$GitRepositoryAccessRegistrationStatusEnumMap,
          json['registration_status'],
          unknownValue: GitRepositoryAccessRegistrationStatus.unknown),
      status: $enumDecode(_$GitRepositoryAccessStatusEnumMap, json['status'],
          unknownValue: GitRepositoryAccessStatus.unknown),
      lastError: json['last_error'] as String?,
    );

Map<String, dynamic> _$GitRepositoryAccessToJson(
        _GitRepositoryAccess instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user': instance.user,
      'provider': _$GitRepositoryAccessProviderEnumMap[instance.provider]!,
      'repository': instance.repository,
      'purpose': instance.purpose,
      'credential_mode':
          _$GitRepositoryAccessCredentialModeEnumMap[instance.credentialMode]!,
      'credential': instance.credential,
      'requested_access': _$GitRepositoryAccessRequestedAccessEnumMap[
          instance.requestedAccess]!,
      'registration_status': _$GitRepositoryAccessRegistrationStatusEnumMap[
          instance.registrationStatus]!,
      'status': _$GitRepositoryAccessStatusEnumMap[instance.status]!,
      'last_error': instance.lastError,
    };

const _$GitRepositoryAccessProviderEnumMap = {
  GitRepositoryAccessProvider.github: 'github',
  GitRepositoryAccessProvider.gitlab: 'gitlab',
  GitRepositoryAccessProvider.codeberg: 'codeberg',
  GitRepositoryAccessProvider.unknown: '__unknown__',
};

const _$GitRepositoryAccessCredentialModeEnumMap = {
  GitRepositoryAccessCredentialMode.generatedDeploy: 'generated_deploy',
  GitRepositoryAccessCredentialMode.existingAccount: 'existing_account',
  GitRepositoryAccessCredentialMode.unknown: '__unknown__',
};

const _$GitRepositoryAccessRequestedAccessEnumMap = {
  GitRepositoryAccessRequestedAccess.readOnly: 'read_only',
  GitRepositoryAccessRequestedAccess.readWrite: 'read_write',
  GitRepositoryAccessRequestedAccess.unknown: '__unknown__',
};

const _$GitRepositoryAccessRegistrationStatusEnumMap = {
  GitRepositoryAccessRegistrationStatus.needsRegistration: 'needs_registration',
  GitRepositoryAccessRegistrationStatus.registered: 'registered',
  GitRepositoryAccessRegistrationStatus.revoked: 'revoked',
  GitRepositoryAccessRegistrationStatus.unknown: '__unknown__',
};

const _$GitRepositoryAccessStatusEnumMap = {
  GitRepositoryAccessStatus.pending: 'pending',
  GitRepositoryAccessStatus.ready: 'ready',
  GitRepositoryAccessStatus.error: 'error',
  GitRepositoryAccessStatus.unknown: '__unknown__',
};
