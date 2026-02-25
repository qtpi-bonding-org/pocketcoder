import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

part 'proposal.freezed.dart';
part 'proposal.g.dart';

@freezed
class Proposal with _$Proposal {
  const factory Proposal({
    required String id,
    required String name,
    String? description,
    required String content,
    required ProposalAuthoredBy authoredBy,
    required ProposalStatus status,
  }) = _Proposal;

  factory Proposal.fromRecord(RecordModel record) =>
      Proposal.fromJson(record.toJson());

  factory Proposal.fromJson(Map<String, dynamic> json) =>
      _$ProposalFromJson(json);
}

enum ProposalAuthoredBy {
  @JsonValue('human')
  human,
  @JsonValue('poco')
  poco,
  @JsonValue('__unknown__')
  unknown,
}

enum ProposalStatus {
  @JsonValue('draft')
  draft,
  @JsonValue('approved')
  approved,
  @JsonValue('__unknown__')
  unknown,
}
