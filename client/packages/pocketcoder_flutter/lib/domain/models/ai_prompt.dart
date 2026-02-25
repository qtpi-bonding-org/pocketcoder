import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'ai_prompt.freezed.dart';
part 'ai_prompt.g.dart';

@freezed
class AiPrompt with _$AiPrompt {
  const factory AiPrompt({
    required String id,
    required String name,
    required String body,
  }) = _AiPrompt;

  factory AiPrompt.fromRecord(RecordModel record) =>
      AiPrompt.fromJson(record.toJson());

  factory AiPrompt.fromJson(Map<String, dynamic> json) =>
      _$AiPromptFromJson(json);
}
