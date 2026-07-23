import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'model.freezed.dart';
part 'model.g.dart';

@freezed
abstract class Model with _$Model {
  const factory Model({
    required String id,
    required String name,
    String? displayName,
    required String provider,
    double? contextWindow,
    String? description,
  }) = _Model;

  factory Model.fromRecord(RecordModel record) =>
      Model.fromJson(record.toJson());

  factory Model.fromJson(Map<String, dynamic> json) =>
      _$ModelFromJson(json);
}
