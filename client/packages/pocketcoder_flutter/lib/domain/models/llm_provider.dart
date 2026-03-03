import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'llm_provider.freezed.dart';
part 'llm_provider.g.dart';

@freezed
class LlmProvider with _$LlmProvider {
  const factory LlmProvider({
    required String id,
    required String providerId,
    required String name,
    dynamic envVars,
    dynamic models,
    bool? isConnected,
  }) = _LlmProvider;

  factory LlmProvider.fromRecord(RecordModel record) =>
      LlmProvider.fromJson(record.toJson());

  factory LlmProvider.fromJson(Map<String, dynamic> json) =>
      _$LlmProviderFromJson(json);
}
