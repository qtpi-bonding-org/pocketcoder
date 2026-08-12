// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ssh_key.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SshKey _$SshKeyFromJson(Map<String, dynamic> json) => _SshKey(
      id: json['id'] as String,
      user: json['user'] as String?,
      publicKey: json['public_key'] as String,
      deviceName: json['device_name'] as String?,
      fingerprint: json['fingerprint'] as String,
      algorithm: json['algorithm'] as String?,
      keySize: (json['key_size'] as num?)?.toDouble(),
      comment: json['comment'] as String?,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      lastUsed: json['last_used'] == null
          ? null
          : DateTime.parse(json['last_used'] as String),
      isActive: json['is_active'] as bool?,
      created: json['created'] == null
          ? null
          : DateTime.parse(json['created'] as String),
      updated: json['updated'] == null
          ? null
          : DateTime.parse(json['updated'] as String),
    );

Map<String, dynamic> _$SshKeyToJson(_SshKey instance) => <String, dynamic>{
      'id': instance.id,
      'user': instance.user,
      'public_key': instance.publicKey,
      'device_name': instance.deviceName,
      'fingerprint': instance.fingerprint,
      'algorithm': instance.algorithm,
      'key_size': instance.keySize,
      'comment': instance.comment,
      'expires_at': instance.expiresAt?.toIso8601String(),
      'last_used': instance.lastUsed?.toIso8601String(),
      'is_active': instance.isActive,
      'created': instance.created?.toIso8601String(),
      'updated': instance.updated?.toIso8601String(),
    };
