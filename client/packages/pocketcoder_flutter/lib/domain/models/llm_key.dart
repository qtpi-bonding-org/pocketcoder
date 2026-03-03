import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'llm_key.freezed.dart';
part 'llm_key.g.dart';

@freezed
class LlmKey with _$LlmKey {
  const factory LlmKey({
    required String id,
    required String providerId,
    dynamic envVars,
    required String user,
  }) = _LlmKey;

  factory LlmKey.fromRecord(RecordModel record) =>
      LlmKey.fromJson(record.toJson());

  factory LlmKey.fromJson(Map<String, dynamic> json) =>
      _$LlmKeyFromJson(json);
}
