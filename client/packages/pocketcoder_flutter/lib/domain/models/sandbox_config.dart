import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'sandbox_config.freezed.dart';
part 'sandbox_config.g.dart';

@freezed
abstract class SandboxConfig with _$SandboxConfig {
  const factory SandboxConfig({
    required String id,
    required String name,
    required String harnessModel,
    String? systemPrompt,
  }) = _SandboxConfig;

  factory SandboxConfig.fromRecord(RecordModel record) =>
      SandboxConfig.fromJson(record.toJson());

  factory SandboxConfig.fromJson(Map<String, dynamic> json) =>
      _$SandboxConfigFromJson(json);
}
