import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'question.freezed.dart';
part 'question.g.dart';

@freezed
class Question with _$Question {
  const factory Question({
    required String id,
    required String chat,
    required String question,
    dynamic choices,
    String? reply,
    @JsonKey(unknownEnumValue: QuestionStatus.unknown) required QuestionStatus status,
  }) = _Question;

  factory Question.fromRecord(RecordModel record) =>
      Question.fromJson(record.toJson());

  factory Question.fromJson(Map<String, dynamic> json) =>
      _$QuestionFromJson(json);
}

enum QuestionStatus {
  @JsonValue('asked')
  asked,
  @JsonValue('replied')
  replied,
  @JsonValue('rejected')
  rejected,
  @JsonValue('__unknown__')
  unknown,
}
