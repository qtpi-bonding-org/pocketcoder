import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/evolution/i_evolution_repository.dart';
import 'package:pocketcoder_flutter/domain/models/proposal.dart';
import 'package:pocketcoder_flutter/domain/models/sop.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'evolution_daos.dart';

@LazySingleton(as: IEvolutionRepository)
class EvolutionRepository implements IEvolutionRepository {
  final ProposalDao _proposalDao;
  final SopDao _sopDao;

  EvolutionRepository(this._proposalDao, this._sopDao);

  // --- Proposals ---

  @override
  Future<List<Proposal>> getProposals() async {
    return tryMethod(
      () => _proposalDao.getFullList(sort: '-created'),
      RepositoryException.new,
      'getProposals',
    );
  }

  @override
  Stream<List<Proposal>> watchProposals() {
    return _proposalDao.watch(sort: '-created');
  }

  @override
  Future<Proposal> createProposal(Map<String, dynamic> data) async {
    return tryMethod(
      () => _proposalDao.save(null, data),
      RepositoryException.new,
      'createProposal',
    );
  }

  @override
  Future<void> updateProposal(String id, Map<String, dynamic> data) async {
    await tryMethod(
      () => _proposalDao.save(id, data),
      RepositoryException.new,
      'updateProposal',
    );
  }

  @override
  Future<void> deleteProposal(String id) async {
    await tryMethod(
      () => _proposalDao.delete(id),
      RepositoryException.new,
      'deleteProposal',
    );
  }

  @override
  Future<void> approveProposal(String id) async {
    await tryMethod(
      () => _proposalDao.save(id, {
        'status': 'approved',
        'approved_at': DateTime.now().toIso8601String(),
      }),
      RepositoryException.new,
      'approveProposal',
    );
  }

  // --- SOPs ---

  @override
  Future<List<Sop>> getSops() async {
    return tryMethod(
      () => _sopDao.getFullList(sort: '-created'),
      RepositoryException.new,
      'getSops',
    );
  }

  @override
  Stream<List<Sop>> watchSops() {
    return _sopDao.watch(sort: '-created');
  }

  @override
  Future<Sop> createSop(Map<String, dynamic> data) async {
    return tryMethod(
      () => _sopDao.save(null, data),
      RepositoryException.new,
      'createSop',
    );
  }

  @override
  Future<void> updateSop(String id, Map<String, dynamic> data) async {
    await tryMethod(
      () => _sopDao.save(id, data),
      RepositoryException.new,
      'updateSop',
    );
  }

  @override
  Future<void> deleteSop(String id) async {
    await tryMethod(
      () => _sopDao.delete(id),
      RepositoryException.new,
      'deleteSop',
    );
  }
}
