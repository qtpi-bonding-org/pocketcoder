import 'package:pocketcoder_flutter/domain/models/proposal.dart';
import 'package:pocketcoder_flutter/domain/models/sop.dart';

abstract class IEvolutionRepository {
  // --- Proposals ---
  Future<List<Proposal>> getProposals();
  Stream<List<Proposal>> watchProposals();
  Future<Proposal> createProposal(Map<String, dynamic> data);
  Future<void> updateProposal(String id, Map<String, dynamic> data);
  Future<void> deleteProposal(String id);

  // --- SOPs ---
  Future<List<Sop>> getSops();
  Stream<List<Sop>> watchSops();
  Future<Sop> createSop(Map<String, dynamic> data);
  Future<void> updateSop(String id, Map<String, dynamic> data);
  Future<void> deleteSop(String id);
}
