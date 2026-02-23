import 'sop.dart';
import '../proposal/proposal.dart';

abstract class ISopRepository {
  Stream<List<Sop>> watchSops();
  Stream<List<Proposal>> watchProposals();
  Future<void> approveProposal(String id);
  Future<void> createProposal(Proposal proposal);
}
