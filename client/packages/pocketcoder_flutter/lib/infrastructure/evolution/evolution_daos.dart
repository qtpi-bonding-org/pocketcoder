import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/proposal.dart';
import 'package:pocketcoder_flutter/domain/models/sop.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';
import "package:flutter_aeroform/infrastructure/core/collections.dart";

@lazySingleton
class ProposalDao extends BaseDao<Proposal> {
  ProposalDao(PocketBase pb)
      : super(pb, Collections.proposals, Proposal.fromJson);
}

@lazySingleton
class SopDao extends BaseDao<Sop> {
  SopDao(PocketBase pb) : super(pb, Collections.sops, Sop.fromJson);
}
