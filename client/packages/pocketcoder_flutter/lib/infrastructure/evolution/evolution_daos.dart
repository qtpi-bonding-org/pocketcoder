import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../domain/proposal/proposal.dart';
import '../../domain/sop/sop.dart';
import '../core/base_dao.dart';
import '../core/collections.dart';

@lazySingleton
class ProposalDao extends BaseDao<Proposal> {
  ProposalDao(PocketBase pb)
      : super(pb, Collections.proposals, Proposal.fromJson);
}

@lazySingleton
class SopDao extends BaseDao<Sop> {
  SopDao(PocketBase pb) : super(pb, Collections.sops, Sop.fromJson);
}
