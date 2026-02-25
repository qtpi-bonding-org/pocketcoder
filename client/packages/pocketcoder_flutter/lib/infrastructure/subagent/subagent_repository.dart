import 'package:injectable/injectable.dart';
import '../../domain/subagent/i_subagent_repository.dart';
import '../../domain/subagent/subagent.dart';
import '../../domain/exceptions.dart';
import '../../core/try_operation.dart';
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
