import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'poco_config.freezed.dart';
part 'poco_config.g.dart';

@freezed
class PocoConfig with _$PocoConfig {
  const factory PocoConfig({
    required String id,
    required String name,
    required String harnessModel,
    String? systemPrompt,
    dynamic workspaceFolders,
    dynamic acpMcpServers,
    bool? isDefault,
  }) = _PocoConfig;

  factory PocoConfig.fromRecord(RecordModel record) =>
      PocoConfig.fromJson(record.toJson());

  factory PocoConfig.fromJson(Map<String, dynamic> json) =>
      _$PocoConfigFromJson(json);
}
