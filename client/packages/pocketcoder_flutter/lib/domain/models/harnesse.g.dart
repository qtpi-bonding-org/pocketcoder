// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'harnesse.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Harnesse _$HarnesseFromJson(Map<String, dynamic> json) => _Harnesse(
      id: json['id'] as String,
      name: json['name'] as String,
      cliId: json['cli_id'] as String,
      version: json['version'] as String?,
      description: json['description'] as String?,
      acpTransport: $enumDecode(
          _$HarnesseAcpTransportEnumMap, json['acp_transport'],
          unknownValue: HarnesseAcpTransport.unknown),
      containerImage: json['container_image'] as String?,
      launchTemplate: json['launch_template'],
      supportsLiveConfig: json['supports_live_config'] as bool?,
      providerScope: $enumDecodeNullable(
          _$HarnesseProviderScopeEnumMap, json['provider_scope'],
          unknownValue: HarnesseProviderScope.unknown),
      supportsOllama: json['supports_ollama'] as bool?,
      supportsSessionDelete: json['supports_session_delete'] as bool?,
      supportsAdditionalDirectories:
          json['supports_additional_directories'] as bool?,
    );

Map<String, dynamic> _$HarnesseToJson(_Harnesse instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'cli_id': instance.cliId,
      'version': instance.version,
      'description': instance.description,
      'acp_transport': _$HarnesseAcpTransportEnumMap[instance.acpTransport]!,
      'container_image': instance.containerImage,
      'launch_template': instance.launchTemplate,
      'supports_live_config': instance.supportsLiveConfig,
      'provider_scope': _$HarnesseProviderScopeEnumMap[instance.providerScope],
      'supports_ollama': instance.supportsOllama,
      'supports_session_delete': instance.supportsSessionDelete,
      'supports_additional_directories': instance.supportsAdditionalDirectories,
    };

const _$HarnesseAcpTransportEnumMap = {
  HarnesseAcpTransport.websocket: 'websocket',
  HarnesseAcpTransport.stdio: 'stdio',
  HarnesseAcpTransport.http: 'http',
  HarnesseAcpTransport.unknown: '__unknown__',
};

const _$HarnesseProviderScopeEnumMap = {
  HarnesseProviderScope.any: 'any',
  HarnesseProviderScope.self: 'self',
  HarnesseProviderScope.unknown: '__unknown__',
};
