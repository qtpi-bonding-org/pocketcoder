import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'model_selection.freezed.dart';
part 'model_selection.g.dart';

@freezed
class ModelSelection with _$ModelSelection {
  const factory ModelSelection({
    required String id,
    required String model,
    required String user,
    String? chat,
  }) = _ModelSelection;

  factory ModelSelection.fromRecord(RecordModel record) =>
      ModelSelection.fromJson(record.toJson());

  factory ModelSelection.fromJson(Map<String, dynamic> json) =>
      _$ModelSelectionFromJson(json);
}
