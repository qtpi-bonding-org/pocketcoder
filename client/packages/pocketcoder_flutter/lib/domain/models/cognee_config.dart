import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'cognee_config.freezed.dart';
part 'cognee_config.g.dart';

@freezed
abstract class CogneeConfig with _$CogneeConfig {
  const factory CogneeConfig({
    required String id,
    required String llmProvider,
    required String llmModel,
    String? llmBaseUrl,
    required String llmApiKey,
  }) = _CogneeConfig;

  factory CogneeConfig.fromRecord(RecordModel record) =>
      CogneeConfig.fromJson(record.toJson());

  factory CogneeConfig.fromJson(Map<String, dynamic> json) =>
      _$CogneeConfigFromJson(json);
}
