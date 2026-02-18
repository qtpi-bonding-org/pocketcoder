import 'package:freezed_annotation/freezed_annotation.dart';

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
    @JsonKey(name: 'approved_at') DateTime? approvedAt,
    @JsonKey(name: 'proposal') String? proposalId,
    @JsonKey(name: 'sealed_at') DateTime? sealedAt,
    @JsonKey(name: 'sealed_by') String? sealedBy,
    int? version,
    DateTime? created,
    DateTime? updated,
  }) = _Sop;

  factory Sop.fromJson(Map<String, dynamic> json) => _$SopFromJson(json);
}
