import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'sop.freezed.dart';
part 'sop.g.dart';

@freezed
class Sop with _$Sop {
  const factory Sop({
    required String id,
    required String name,
    required String description,
    required String content,
    required String signature,
    DateTime? approvedAt,
    String? proposal,
    DateTime? sealedAt,
    String? sealedBy,
    double? version,
  }) = _Sop;

  factory Sop.fromRecord(RecordModel record) =>
      Sop.fromJson(record.toJson());

  factory Sop.fromJson(Map<String, dynamic> json) =>
      _$SopFromJson(json);
}
