import 'package:pocketcoder_flutter/domain/models/sop.dart';
import 'package:pocketcoder_flutter/domain/models/proposal.dart';

abstract class ISopRepository {
  Stream<List<Sop>> watchSops();
  Stream<List<Proposal>> watchProposals();
  Future<void> approveProposal(String id);
  Future<void> createProposal(Proposal proposal);
}
