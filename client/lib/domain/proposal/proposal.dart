import 'package:freezed_annotation/freezed_annotation.dart';

part 'proposal.freezed.dart';
part 'proposal.g.dart';

@freezed
class Proposal with _$Proposal {
  const factory Proposal({
    required String id,
    required String name,
    String? description,
    required String content,
    @JsonKey(name: 'authored_by') required ProposalAuthor authoredBy,
    required ProposalStatus status,
    DateTime? created,
    DateTime? updated,
  }) = _Proposal;

  factory Proposal.fromJson(Map<String, dynamic> json) =>
      _$ProposalFromJson(json);
}

enum ProposalAuthor {
  @JsonValue('human')
  human,
  @JsonValue('poco')
  poco,
  @JsonValue('')
  unknown,
}

enum ProposalStatus {
  @JsonValue('draft')
  draft,
  @JsonValue('approved')
  approved,
  @JsonValue('')
  unknown,
}
