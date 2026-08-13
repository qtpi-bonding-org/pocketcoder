import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'prompt.freezed.dart';
part 'prompt.g.dart';

@freezed
abstract class Prompt with _$Prompt {
  const factory Prompt({
    required String id,
    required String name,
    required String body,
    String? user,
    bool? isSystem,
  }) = _Prompt;

  factory Prompt.fromRecord(RecordModel record) =>
      Prompt.fromJson(record.toJson());

  factory Prompt.fromJson(Map<String, dynamic> json) =>
      _$PromptFromJson(json);
}
