import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'harnesse.freezed.dart';
part 'harnesse.g.dart';

@freezed
abstract class Harnesse with _$Harnesse {
  const factory Harnesse({
    required String id,
    required String name,
    required String cliId,
    String? version,
    String? description,
    @JsonKey(unknownEnumValue: HarnesseAcpTransport.unknown)
    required HarnesseAcpTransport acpTransport,
    String? containerImage,
    dynamic launchTemplate,
    bool? supportsLiveConfig,
    bool? supportsLiveCredentialRegistration,
    bool? providerFanout,
    bool? supportsOllama,
    bool? supportsSessionDelete,
    bool? supportsAdditionalDirectories,
  }) = _Harnesse;

  factory Harnesse.fromRecord(RecordModel record) =>
      Harnesse.fromJson(record.toJson());

  factory Harnesse.fromJson(Map<String, dynamic> json) =>
      _$HarnesseFromJson(json);
}

enum HarnesseAcpTransport {
  @JsonValue('websocket')
  websocket,
  @JsonValue('stdio')
  stdio,
  @JsonValue('http')
  http,
  @JsonValue('__unknown__')
  unknown,
}
