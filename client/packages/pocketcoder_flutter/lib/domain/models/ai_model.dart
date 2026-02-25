import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'ai_model.freezed.dart';
part 'ai_model.g.dart';

@freezed
class AiModel with _$AiModel {
  const factory AiModel({
    required String id,
    required String name,
    required String identifier,
  }) = _AiModel;

  factory AiModel.fromRecord(RecordModel record) =>
      AiModel.fromJson(record.toJson());

  factory AiModel.fromJson(Map<String, dynamic> json) =>
      _$AiModelFromJson(json);
}
