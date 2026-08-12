// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_server.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_McpServer _$McpServerFromJson(Map<String, dynamic> json) => _McpServer(
      id: json['id'] as String,
      name: json['name'] as String,
      status: $enumDecode(_$McpServerStatusEnumMap, json['status'],
          unknownValue: McpServerStatus.unknown),
      requestedBy: json['requested_by'] as String?,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] == null
          ? null
          : DateTime.parse(json['approved_at'] as String),
      config: json['config'],
      catalog: json['catalog'] as String?,
      reason: json['reason'] as String?,
      image: json['image'] as String?,
      configSchema: json['config_schema'],
      oauthProvider: json['oauth_provider'] as String?,
      oauthTokenEnvVar: json['oauth_token_env_var'] as String?,
      created: json['created'] == null
          ? null
          : DateTime.parse(json['created'] as String),
      updated: json['updated'] == null
          ? null
          : DateTime.parse(json['updated'] as String),
      acpTransport: $enumDecodeNullable(
          _$McpServerAcpTransportEnumMap, json['acp_transport'],
          unknownValue: McpServerAcpTransport.unknown),
    );

Map<String, dynamic> _$McpServerToJson(_McpServer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'status': _$McpServerStatusEnumMap[instance.status]!,
      'requested_by': instance.requestedBy,
      'approved_by': instance.approvedBy,
      'approved_at': instance.approvedAt?.toIso8601String(),
      'config': instance.config,
      'catalog': instance.catalog,
      'reason': instance.reason,
      'image': instance.image,
      'config_schema': instance.configSchema,
      'oauth_provider': instance.oauthProvider,
      'oauth_token_env_var': instance.oauthTokenEnvVar,
      'created': instance.created?.toIso8601String(),
      'updated': instance.updated?.toIso8601String(),
      'acp_transport': _$McpServerAcpTransportEnumMap[instance.acpTransport],
    };

const _$McpServerStatusEnumMap = {
  McpServerStatus.pending: 'pending',
  McpServerStatus.approved: 'approved',
  McpServerStatus.denied: 'denied',
  McpServerStatus.revoked: 'revoked',
  McpServerStatus.unknown: '__unknown__',
};

const _$McpServerAcpTransportEnumMap = {
  McpServerAcpTransport.http: 'http',
  McpServerAcpTransport.sse: 'sse',
  McpServerAcpTransport.stdio: 'stdio',
  McpServerAcpTransport.unknown: '__unknown__',
};
