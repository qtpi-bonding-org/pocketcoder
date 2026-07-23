import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'harness_model.freezed.dart';
part 'harness_model.g.dart';

@freezed
abstract class HarnessModel with _$HarnessModel {
  const factory HarnessModel({
    required String id,
    required String harness,
    required String model,
    required String harnessModelId,
    bool? isDefault,
  }) = _HarnessModel;

  factory HarnessModel.fromRecord(RecordModel record) =>
      HarnessModel.fromJson(record.toJson());

  factory HarnessModel.fromJson(Map<String, dynamic> json) =>
      _$HarnessModelFromJson(json);
}
