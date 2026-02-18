import 'package:freezed_annotation/freezed_annotation.dart';

part 'sop.freezed.dart';
part 'sop.g.dart';

@freezed
class Sop with _$Sop {
  const factory Sop({
    required String id,
    required String name,
    String? description,
    required String content,
    String? signature,
    @JsonKey(name: 'approved_at') DateTime? approvedAt,
    DateTime? created,
    DateTime? updated,
  }) = _Sop;

  factory Sop.fromJson(Map<String, dynamic> json) => _$SopFromJson(json);
}