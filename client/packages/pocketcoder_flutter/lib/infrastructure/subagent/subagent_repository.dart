import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/subagent/i_subagent_repository.dart';
import 'package:pocketcoder_flutter/domain/models/subagent.dart';
import 'package:flutter_aeroform/domain/exceptions.dart';
import 'package:flutter_aeroform/core/try_operation.dart';
import '../communication/communication_daos.dart';

@LazySingleton(as: ISubagentRepository)
class SubagentRepository implements ISubagentRepository {
  final SubagentDao _subagentDao;

  SubagentRepository(this._subagentDao);

  @override
  Stream<List<Subagent>> watchSubagents(String chatId) {
    return _subagentDao.watch(filter: 'chat = "$chatId"');
  }

  @override
  Future<void> terminateSubagent(String id) async {
    return tryMethod(
      () async {
        await _subagentDao.delete(id);
      },
      RepositoryException.new,
      'terminateSubagent',
    );
  }
}
