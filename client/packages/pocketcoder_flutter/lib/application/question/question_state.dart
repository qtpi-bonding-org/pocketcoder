import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/question.dart';

part 'question_state.freezed.dart';

@freezed
class QuestionState with _$QuestionState {
  const factory QuestionState.initial() = _Initial;
  const factory QuestionState.loading() = _Loading;
  const factory QuestionState.loaded(List<Question> questions) = _Loaded;
  const factory QuestionState.error(String message) = _Error;
}
